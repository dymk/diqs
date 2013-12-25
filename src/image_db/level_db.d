module image_db.level_db;

import image_db.all;
import image_db.bucket_manager;
import image_db.level_db_listeners;

import sig;

import msgpack;
import deimos.leveldb.leveldb;

import std.stdio;
import std.string : toStringz;
import std.conv : to;
import std.algorithm;
import std.file;
import std.exception;
import std.path : buildPath;

// Read options for iterators and write for DB writes
private __gshared leveldb_readoptions_t ReadOptions;
private __gshared leveldb_writeoptions_t WriteOptions;
shared static this()
{
	ReadOptions = leveldb_readoptions_create();
	WriteOptions = leveldb_writeoptions_create();
}
shared static ~this()
{
	leveldb_readoptions_destroy(ReadOptions);
	ReadOptions = null;

	leveldb_writeoptions_destroy(WriteOptions);
	WriteOptions = null;
}

final class LevelDb : PersistableDb, ImageRemovableDb, BaseDb
{
private:
	// The backing leveldb implementation
	leveldb_t db;
	leveldb_options_t opts;

	// Location in the filesystem of the database
	string db_path;

	// msgpacked BucketSizes*
	immutable string bs_path;

	// A reference to all iterators is kept so they can be closed when the DB is closed
	LevelDbImageIterator[] iterators;

	// On image change listeners
	DbImageChangeListener[] image_change_listeners;

	// Change listeners for tracking DB state
	BucketSizeTracker bs_tracker;
	NumImageCounter num_image_counter;
	IdTracker id_tracker;
	MemDbImageTracker mem_db_tracker;

public:
	this(string db_path, bool create_if_missing = false)
	{
		this.db_path = db_path;

		opts = enforce(leveldb_options_create(), "Failed to prepare DB open/create");
		leveldb_options_set_create_if_missing(opts, create_if_missing);

		char* errptr = null;
		scope(failure) if(errptr !is null) leveldb_free(errptr);

		this.db = leveldb_open(opts, db_path.toStringz(), &errptr);

		if(errptr)
		{
			auto errptr_str = errptr.to!string();
			if(errptr_str.canFind("nonexistant") || errptr_str.canFind("not exist"))
			{
				throw new PersistableDb.DbNonexistantException(errptr.to!string);
			}
		}

		enforce(errptr is null, errptr.to!string);

		this.bs_path = buildPath(db_path, "BUCKET_SIZES");

		num_image_counter = new NumImageCounter();
		bs_tracker = new BucketSizeTracker();
		id_tracker = new IdTracker(100);

		image_change_listeners.reserve(10);

		this.addImageChangeListener(num_image_counter);
		this.addImageChangeListener(bs_tracker);
		this.addImageChangeListener(id_tracker);

		load();
	}

	~this()
	{
		close();
		leveldb_options_destroy(opts);
	}

	void addImageChangeListener(DbImageChangeListener listener)
	{
		if(listener !is null)
		{
			image_change_listeners ~= listener;
		}
	}

	void removeImageChangeListener(DbImageChangeListener listener)
	{
		image_change_listeners = std.algorithm.remove!((l) => l is listener, SwapStrategy.unstable)(image_change_listeners);
	}

	bool getImage(user_id_t user_id, ImageIdSigDcRes* img) const
	{
		if(!id_tracker.filter.test(user_id))
		{
			return false;
		}

		char* errptr = null;
		scope(exit) if(errptr) leveldb_free(errptr);

		size_t vallen;
		auto valptr = leveldb_get(
			cast(void*) db,
			ReadOptions,
			cast(char*) &user_id,
			user_id_t.sizeof,
			&vallen,
			&errptr);

		scope(exit) if(valptr) leveldb_free(valptr);

		if (valptr) return false;

		enforce(vallen == ImageIdSigDcRes.sizeof, "Returned value in DB isn't the size of an image");
		if(img !is null)
		{
			*img = *(cast(ImageIdSigDcRes*) valptr);
		}

		return true;
	}

	bool getImage(user_id_t user_id) const
	{
		return getImage(user_id, null);
	}

	void removeImage(user_id_t user_id, ImageIdSigDcRes* ret_img)
	{
		ImageIdSigDcRes persisted_ret;
		auto was_in_level = getImage(user_id, &persisted_ret);

		enforce(was_in_level);

		char* errptr = null;
		scope(exit) if(errptr) leveldb_free(errptr);

		leveldb_delete(db, WriteOptions, cast(char*) &user_id, typeid(user_id).sizeof, &errptr);

		// Perhaps, this can be made a warning, although it is concerning that
		// the memdb was out of sync with the persisted db
		enforce(errptr is null, "LevelDb Error: " ~ errptr.to!string);

		if(ret_img != null)
		{
			*ret_img = persisted_ret;
		}

		foreach(listener; image_change_listeners)
		{
			listener.onImageRemoved(user_id, &(ret_img.sig), &(ret_img.dc), &(ret_img.res));
		}
	}

	void removeImage(user_id_t user_id)
	{
		removeImage(user_id, null);
	}

	uint numImages() const
	{
		return num_image_counter.get;
	}

	// TODO: Make this do something more useful.
	bool flush() { return true; }
	bool dirty() const { return false;}

	bool closed() const { return db is null; }

	void close()
	{
		if(!closed())
		{
			scope bs_packed = msgpack.pack(bs_tracker.get);
			std.file.write(bs_path, bs_packed);

			foreach(iter; this.iterators)
			{
				iter.close();
			}

			leveldb_close(db);
			db = null;
		}
	}

	LevelDbImageIterator imageDataIterator()
	{
		auto iter = new LevelDbImageIterator(db);
		iterators ~= iter;
		return iter;
	}

	string path() const
	{
		return db_path;
	}

	void makeQueryable()
	out
	{
		assert(
			mem_db_tracker.get.numImages() == num_image_counter.get,
			"Num images didn't match");
	}
	body
	{
		if(mem_db_tracker !is null)
		{
			return;
		}

		mem_db_tracker = new MemDbImageTracker();

		writefln("Populating MemDb, reserving space for %d images", num_image_counter.get);
		MemDb mdb = mem_db_tracker.get;

		mdb.reserve(num_image_counter.get);
		mdb.bucketSizeHint(bs_tracker.get);

		foreach(ref img; this.imageDataIterator())
		{
			mdb.addImage(&img);
		}

		addImageChangeListener(mem_db_tracker);
	}

	void destroyQueryable()
	{
		removeImageChangeListener(mem_db_tracker);
		MemDb mdb = mem_db_tracker.get;
		mdb.destroy();
		mem_db_tracker.destroy();

		mem_db_tracker = null;
	}

	QueryableDb getQueryable()
	{
		if(mem_db_tracker is null)
		{
			return null;
		}
		return mem_db_tracker.get;
	}

	/**
	 * Inserts an image without a yet determind ID into the database
	 * and returns its assigned ID. The database will determine what
	 * ID to give the image.
	 */
	user_id_t addImage(user_id_t user_id, const(ImageSigDcRes*) img)
	{
		auto id_img = ImageIdSigDcRes.fromSigDcRes(user_id, *img);
		return addImage(&id_img);
	}

	user_id_t addImage(const(ImageSigDcRes*) img)
	{
		auto img_id = id_tracker.gen.next();
		auto id_img = ImageIdSigDcRes.fromSigDcRes(img_id, *img);
		addImageToLevel(&id_img);
		return img_id;
	}

	user_id_t addImage(const(ImageIdSigDcRes*) img)
	{
		if(getImage(img.user_id))
		{
			throw new BaseDb.AlreadyHaveIdException(img.user_id);
		}
		addImageToLevel(img);
		return img.user_id;
	}

private:
	void load()
	{
		bool rebuild_bucket_sizes = false;

		if(exists(bs_path))
		{
			try
			{
				scope bs_packed = cast(ubyte[]) std.file.read(bs_path);
				BucketSizes sizes;
				msgpack.unpack(bs_packed, sizes);
				*(bs_tracker.get) = sizes;
			}
			catch(MessagePackException e)
			{
				// The msgpacked file wasn't valid; recreate it
				rebuild_bucket_sizes = true;

				try
				{
					std.file.remove(bs_path);
				}
				catch(FileException e) {}
			}
		}

		foreach(ref img; imageDataIterator())
		{
			id_tracker.onImageAdded(img.user_id, null, null, null);
			num_image_counter.onImageAdded(img.user_id, null, null, null);

			if(rebuild_bucket_sizes)
			{
				bs_tracker.onImageAdded(img.user_id, &(img.sig), null, null);
			}
		}
	}

	void addImageToLevel(const(ImageIdSigDcRes*) img)
	{
		char* errptr = null;
		scope(exit) if(errptr) leveldb_free(errptr);

		// TODO: add support for batch image insertions

		// Also, TODO: Perhaps it should write an ImageSigDcRes instead of including
		// the ID, but well, for now this makes iterating really easy
		leveldb_put(db, WriteOptions,
			cast(char*) &(img.user_id),
			user_id_t.sizeof,
			cast(char*) img,
			ImageIdSigDcRes.sizeof, &errptr);

		enforce(errptr is null, "LevelDb error: " ~ errptr.to!string);

		foreach(listener; image_change_listeners)
		{
			listener.onImageAdded(img.user_id, &(img.sig), &(img.dc), &(img.res));
		}
	}

	// Iterator for image data within the leveldb
	final static class LevelDbImageIterator : ImageDataIterator
	{
		this(leveldb_t db)
		{
			_iter = enforce(leveldb_create_iterator(db, ReadOptions));
			leveldb_iter_seek_to_first(_iter);
		}

		~this()
		{
			close();
		}

		user_id_t key() const
		{
			size_t keylen;
			auto key = leveldb_iter_key(enforceIter, &keylen);
			scope(failure) if(key) leveldb_free(cast(void*) key);

			enforce(keylen == user_id_t.sizeof);

			return *(cast(user_id_t*) key);
		}

		ImageIdSigDcRes value() const
		{
			size_t vallen;
			auto val = leveldb_iter_value(enforceIter, &vallen);
			scope(failure) if(val) leveldb_free(cast(void*) val);

			enforce(vallen == ImageIdSigDcRes.sizeof, "DB ret size was " ~ vallen.to!string ~ " should have been " ~ ImageIdSigDcRes.sizeof.to!string);

			return *(cast(ImageIdSigDcRes*) val);
		}

		ImageIdSigDcRes front() const { return value(); }
		bool empty()            const { return leveldb_iter_valid(enforceIter) == 0 ? true : false; }
		void popFront()               { return leveldb_iter_next(enforceIter); }

		void close()
		out
		{
			assert(_iter is null);
		}
		body
		{
			if(_iter !is null)
			{
				leveldb_iter_destroy(_iter);
				_iter = null;
			}
		}

	private:
		inout(leveldb_iterator_t) enforceIter() inout @property
		{
			return enforce(_iter, "Iterator has been closed");
		}

		leveldb_iterator_t _iter;
	}
}

version(unittest)
{
	const __gshared const(string) temp_dir;
	shared static this()
	{
		temp_dir = buildPath(tempDir(), "leveldb_backed_tmp");

		try
		{
			mkdirRecurse(temp_dir);
		} catch (Exception e) {}
	}

	shared static ~this()
	{
		try
		{
			rmdirRecurse(temp_dir);
		} catch (Exception e) {}
	}

	string getTempPath(string base)
	{
		return buildPath(temp_dir, base);
	}

	// Returns a new, unique LevelDb
	static int ldb_num = 0;
	static immutable leveldb_options_t temp_destroy_opts;

	static this()
	{
		temp_destroy_opts = cast(immutable(void*)) enforce(leveldb_options_create());
	}

	LevelDb getTempLevelDb()
	{
		string tmp_path = getTempPath(ldb_num.to!string);

		char* errptr = null;
		leveldb_destroy_db(temp_destroy_opts, tmp_path.toStringz(), &errptr);

		enforce(errptr is null, errptr.to!string);

		try {
			rmdirRecurse(tmp_path);
		} catch(Exception e) {}

		scope(exit) { ldb_num++; }
		return new LevelDb(tmp_path, true);
	}
}

unittest
{
	scope(exit)
	{
		try { rmdirRecurse("test/nonexistant"); }
		catch(Exception e) {}
	}

	bool thrown = false;
	try
	{
		new LevelDb("test/nonexistant");
	}
	catch(PersistableDb.DbNonexistantException e)
	{
		thrown = true;
	}
	catch(Exception e) { writeln("Wrong exception thrown: ", e.msg); }
	assert(thrown);
}

unittest
{
	scope db = getTempLevelDb();
	assert(!db.closed());
}

unittest
{
	scope db = getTempLevelDb();
	foreach(image; db.imageDataIterator())
	{
		assert(false);
	}
}

unittest
{
	scope db = getTempLevelDb();
	auto img_data = imageFromFile("test/cat_a1.jpg");

	auto image_id = db.addImage(&img_data);
	assert(db.imageDataIterator().empty == false);
}

unittest
{
	scope db = getTempLevelDb();
	auto img_data = imageFromFile("test/cat_a1.jpg");

	auto image_id = db.addImage(&img_data);

	bool iterated = false;
	foreach(image; db.imageDataIterator())
	{
		iterated = true;
		assert(image.user_id == image_id);
		assert(image.sig == img_data.sig);
		assert(image.dc == img_data.dc);
		assert(image.res == img_data.res);
	}

	assert(iterated);
}

unittest
{
	scope db = getTempLevelDb();
	auto img_data = imageFromFile("test/cat_a1.jpg");

	assert(db.numImages() == 0);
	auto image_id = db.addImage(&img_data);

	auto memdb = db.exportMemDb();
	assert(memdb.numImages() == 1);
}
