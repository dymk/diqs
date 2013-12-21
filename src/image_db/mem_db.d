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

final class MemDb : BaseDb, ReservableDb, QueryableDb
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
	 * Adds an image onto the database. Multiple overloads
	 * so the user can choose to have an ID chosen for them,
	 * or explicitly specify the ID they'd like to refer to the
	 * image with.
	 */

	user_id_t addImage(user_id_t user_id, const(ImageSig*) sig, const(ImageDc*) dc)
	body
	{
		id_mutex.lock();
		scope(exit) { id_mutex.unlock(); }

		m_id_gen.saw(user_id);

		// Next ID is just the next available spot in the in-mem array
		immutable intern_id_t intern_id = cast(intern_id_t) m_mem_imgs.length;

		m_mem_imgs.length = max(m_mem_imgs.length, intern_id+1);
		m_mem_imgs[intern_id] = StoredImage(user_id, *dc);

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

// TODO: Have MemDb check if an ID has already been inserted
//unittest {
//	auto db = new MemDb();
//	db.addImage(&img1);

//	bool thrown = false;
//	try {
//		db.addImage(&img1);
//	}
//	catch(BaseDb.AlreadyHaveIdException e)
//	{
//		thrown = true;
//	}
//	assert(thrown, "BaseDb.AlreadyHaveIdException wasn't thrown");
//}

unittest {
	auto db = new MemDb;
	auto id1 = db.addImage(&img1);
	auto id2 = db.addImage(&img2);

	assert(db.numImages() == 2);
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
