module image_db.mem_db;

/**
 * Represents an in memory, searchable database of images
 */

import image_db.bucket_manager;
import image_db.all;
import types :
  user_id_t,
  intern_id_t;

import sig;

import query :
  QueryResult,
  QueryParams;

import std.stdio;
import std.algorithm : min, max;
import std.exception : enforce;
import core.sync.mutex;

final class MemDb : BaseDb, ReservableDb
{
	alias StoredImage = ImageIdDc;

	/// Loads the database from the file in db_path
	this()
	{
		m_manager = new BucketManager();
		m_id_gen = new shared IdGen!user_id_t();
		id_mutex = new Mutex;
	}

	this(size_t size_hint)
	{
		this();
		reserve(size_hint);
	}

	/**
	 * Determine if the database holds an image with that user ID
	 * If it does, return a pointer to the image's information,
	 * else, return null.
	 */
	const(StoredImage)* has(user_id_t id)
	{
		id_mutex.lock();
		scope(exit) { id_mutex.unlock(); }

		const intern_id = id in id_intern_map;
		if(intern_id is null)
		{
			return null;
		}
		return cast(StoredImage*) &m_mem_imgs[*intern_id];
	}

	/**
	 * Similar to has(), but throws an error if throwOnNotFound is true
	 * and the image isn't found in the database. Else returns null, or
	 * a pointer to the image's data.
	 */
	const(StoredImage)* getImage(user_id_t id)
	{
		auto img = has(id);
		if(img is null) {
			throw new BaseDb.IdNotFoundException(id);
		}
		return img;
	}

	/**
	 * Adds an image onto the database. Multiple overloads
	 * so the user can choose to have an ID chosen for them,
	 * or explicitly specify the ID they'd like to refer to the
	 * image with.
	 */

	user_id_t addImage(user_id_t user_id, const(ImageSig*) sig, const(ImageDc*) dc)
	body
	{
		m_id_gen.saw(user_id);

		id_mutex.lock();
		scope(exit) { id_mutex.unlock(); }

		if(user_id in id_intern_map)
		{
			throw new BaseDb.AlreadyHaveIdException(user_id);
		}
		// Next ID is just the next available spot in the in-mem array
		immutable intern_id_t intern_id = cast(intern_id_t) m_mem_imgs.length;

		m_mem_imgs.length = max(m_mem_imgs.length, intern_id+1);
		m_mem_imgs[intern_id] = StoredImage(user_id, *dc);

		id_intern_map[user_id] = intern_id;

		m_manager.addSig(intern_id, *sig);

		// Arbitrary limit so the user can't have more than 4B
		// images in the database (and they don't overflow
		// internal IDs).
		enforce(m_mem_imgs.length <= intern_id_t.max, "Error, can't have more than 2^32 images in one DB!");

		return user_id;
	}

	user_id_t addImage(const(ImageSigDcRes*) img)
	{
		user_id_t user_id = m_id_gen.next();
		return addImage(user_id, &(img.sig), &(img.dc));
	}

	user_id_t addImage(user_id_t user_id, const(ImageSigDcRes*) img)
	{
		return addImage(user_id, &(img.sig), &(img.dc));
	}

	user_id_t addImage(const(ImageIdSigDcRes*) img)
	{
		return addImage(img.user_id, &(img.sig), &(img.dc));
	}

	/**
	 * Removes an image from the database, and returns the associated signature.
	 */
	void removeImage(user_id_t user_id, ImageIdSigDc* ret_image)
	{
		id_mutex.lock();
		scope(exit) { id_mutex.unlock(); }

		// Map to the internal ID
		auto maybe_rm_id = user_id in id_intern_map;
		if(maybe_rm_id is null)
		{
			throw new BaseDb.IdNotFoundException(user_id);
		}

		immutable rm_intern_id = *maybe_rm_id;
		immutable rm_image     = m_mem_imgs[rm_intern_id];

		ImageSig sig = m_manager.removeId(rm_intern_id);

		id_intern_map.remove(user_id);

		if(rm_intern_id != m_mem_imgs.length-1)
		{
			// The image removed wasn't the last one in the store; move
			// the one at the end to where the removed one previously was
			immutable StoredImage last_image = m_mem_imgs[$-1];
			immutable intern_id_t last_intern_id = cast(intern_id_t) (m_mem_imgs.length - 1);
			immutable user_id_t   last_user_id = last_image.user_id;

			m_mem_imgs[rm_intern_id] = last_image;
			id_intern_map[last_user_id] = rm_intern_id;

			immutable last_image_sig = m_manager.removeId(last_intern_id);
			m_manager.addSig(rm_intern_id, last_image_sig);
		}

		m_mem_imgs.length--;

		if(ret_image !is null)
		{
			*ret_image = ImageIdSigDc(user_id, sig, rm_image.dc);
		}
	}

	void removeImage(user_id_t user_id)
	{
		removeImage(user_id, null);
	}

	uint numImages() const
	{
		return cast(uint) m_mem_imgs.length;
	}

	user_id_t peekNextId() const
	{
		return m_id_gen.peek();
	}

	QueryResult[] query(QueryParams params) const
	{
		return params.perform(cast(BucketManager) m_manager, m_mem_imgs);
	}

	auto bucketSizeHint(BucketSizes* sizes)
	{
		return m_manager.bucketSizeHint(sizes);
	}

	auto bucketSizes()
	{
		return m_manager.bucketSizes();
	}

	void reserve(size_t amt)
	{
		m_mem_imgs.reserve(numImages() + amt);
	}

private:
	// Maps a user_id to its index in m_mem_imgs
	//scope immutable(StoredImage)[] m_mem_imgs;
	scope StoredImage[] m_mem_imgs;

	// Maps immutable user IDs to internal IDs
	scope intern_id_t[user_id_t] id_intern_map;

	scope BucketManager m_manager;
	shared IdGen!user_id_t m_id_gen;

	// Mutex that must be held when doing any modifications to the
	// id_intern_map or m_mem_imgs
	Mutex id_mutex;
}

version(unittest)
{
	import sig : imageFromFile;

	static immutable ImageIdSigDcRes img1;
	static immutable ImageIdSigDcRes img2;
	static this() {
		img1 = imageFromFile(1, "test/cat_a1.jpg");
		img2 = imageFromFile(2, "test/small_png.png");
	}
}

unittest {
	// Make sure our test data is of differnet images
	assert(img1.sig.sameAs(img2.sig) == false);
	assert(img1.dc != img2.dc);
	assert(img1.res != img2.res);
}

unittest {
	auto db = new MemDb();
	assert(db.numImages() == 0);

	db.addImage(&img1);

	assert(db.numImages() == 1);
}

unittest {
	auto db = new MemDb();
	db.addImage(&img1);

	bool thrown = false;
	try {
		db.addImage(&img1);
	}
	catch(BaseDb.AlreadyHaveIdException e)
	{
		thrown = true;
	}
	assert(thrown, "BaseDb.AlreadyHaveIdException wasn't thrown");
}

unittest {
	auto db = new MemDb();
	db.addImage(&img1);

	bool thrown = false;
	try {
		db.getImage(123);
	} catch(BaseDb.IdNotFoundException e) {
		thrown = true;
	}
	assert(thrown);
}

unittest {
	auto db = new MemDb();
	auto id = db.addImage(&img1);
	ImageIdSigDc ret;
	db.removeImage(id, &ret);
	assert(ret.sig.sameAs(img1.sig));
}

unittest {
	auto db = new MemDb;

	assert(db.has(0) is null);

	auto id = db.addImage(&img1);
	db.removeImage(id);

	assert(db.has(id) is null);
	assert(db.numImages() == 0);
}

unittest {
	auto db = new MemDb;
	auto id = db.addImage(&img1);
	assert(id == db.getImage(id).user_id);
}

unittest {
	auto db = new MemDb;
	auto id = db.addImage(&img1);
	assert(id == db.getImage(id).user_id);
}

unittest {
	auto db = new MemDb;
	auto id1 = db.addImage(&img1);
	auto id2 = db.addImage(&img2);

	assert(db.numImages() == 2);

	assert(db.getImage(id1).dc == img1.dc);

	assert(db.getImage(id2).dc == img2.dc);

	assert(db.has(id1));
	assert(db.has(id2));

	ImageIdSigDc rm_img1;
	db.removeImage(id1, &rm_img1);
	assert(db.numImages() == 1);

	// Verify the right image is returned from remove
	assert(rm_img1.sig.sameAs(img1.sig));
	assert(rm_img1.dc == img1.dc);

	assert(!db.has(id1));
	assert(db.has(id2));

	ImageIdSigDc rm_img2;
	db.removeImage(id2, &rm_img2);
	assert(!db.has(id2));
	assert(db.numImages() == 0);

	assert(rm_img2.sig.sameAs(img2.sig));
	assert(rm_img2.dc == img2.dc);
}

unittest {
	assert(img1.user_id != img2.user_id);
	assert(img1.dc != img2.dc);
	assert(img1.res != img2.res);
	assert(!img1.sig.sameAs(img2.sig));
}

unittest {
	auto db = new MemDb();
	auto id1 = db.addImage(&img1);
	auto id2 = db.addImage(&img2);

	assert(id1 == img1.user_id);
	assert(id2 == img2.user_id);

	assert(id1 != id2);
}
