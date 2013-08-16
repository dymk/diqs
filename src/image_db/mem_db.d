module image_db.mem_db;

/**
 * Represents an in memory, searchable database of images
 */

import image_db.bucket_manager : BucketManager;
import image_db.base_db : BaseDb, IdGen;
import types :
  user_id_t,
  intern_id_t;
import sig :
	ImageDc,
	ImageRes,
	ImageDcRes,
	ImageSigDcRes,
	ImageIdSigDcRes;

import std.algorithm : min, max;

// TODO: DRY up custom exceptions
class AlreadyHaveIDException : Exception {
	this(string msg = "ID Already inserted in database", string file = __FILE__, size_t line = __LINE__)
	{ super(msg, file, line); }
}

class IDNotFoundException : Exception {
	this(string msg = "ID was not found in the database", string file = __FILE__, size_t line = __LINE__)
	{ super(msg, file, line); }
}

class MemDb : BaseDb
{

	/// Loads the database from the file in db_path
	this()
	{
		//m_user_mem_ids_map = new UserInternMap();
		m_manager = new BucketManager();
		m_id_gen = new IdGen!user_id_t;
	}

	const ImageDcRes* has(user_id_t id)
	{
		const intern_id = id in id_intern_map;
		if(intern_id is null)
		{
			return null;
		}
		return cast(ImageDcRes*) &m_mem_imgs[*intern_id];
	}

	const ImageDcRes* get(user_id_t id, bool throwOnNotFound = true)
	{
		auto img = has(id);
		if(img is null && throwOnNotFound) {
			throw new IDNotFoundException;
		}
		return img;
	}

	bool addImage(in ImageSigDcRes img)
	{
		user_id_t user_id = m_id_gen.next();
		return addImage(img, user_id);
	}

	bool addImage(in ImageSigDcRes img, user_id_t user_id)
	{
		auto idimg = ImageIdSigDcRes(user_id, img.sig, img.dc, img.res);
		return addImage(idimg);
	}

	bool addImage(in ImageIdSigDcRes img)
	{
		immutable user_id = img.user_id;
		if(user_id in id_intern_map)
		{
			throw new AlreadyHaveIDException;
		}

		m_id_gen.saw(user_id);

		// Next ID is just the next available spot in the in-mem array
		immutable intern_id_t intern_id = cast(intern_id_t) m_mem_imgs.length;

		m_mem_imgs.length = max(m_mem_imgs.length, intern_id+1);
		m_mem_imgs[intern_id] = ImageDcRes(img.dc, img.res);

		id_intern_map[user_id] = intern_id;

		m_manager.addSig(intern_id, img.sig);

		return true;
	}

	auto numImages() @property { return m_mem_imgs.length; }

private:
	// Maps a user_id to its index in m_mem_imgs
	scope ImageDcRes[] m_mem_imgs;

	// Maps immutable user IDs to internal IDs
	scope intern_id_t[user_id_t] id_intern_map;

	scope BucketManager m_manager;

	scope IdGen!user_id_t m_id_gen;
}

unittest {
	auto db = new MemDb();
	assert(db.numImages() == 0);

	auto img = ImageSigDcRes.fromFile("test/cat_a1.jpg");
	db.addImage(img);

	assert(db.numImages() == 1);
}

unittest {
	auto db = new MemDb();
	auto img = ImageSigDcRes.fromFile("test/cat_a1.jpg");
	db.addImage(img, 0);
	bool thrown = false;
	try {
		db.addImage(img, 0);
	}
	catch(AlreadyHaveIDException e)
	{
		thrown = true;
	}
	assert(thrown, "AlreadyHaveIDException wasn't thrown");
}

unittest {
	auto db = new MemDb();
	auto img = ImageSigDcRes.fromFile("test/cat_a1.jpg");
	db.addImage(img, 0);
	bool thrown = false;
	assert(db.get(1, false) is null);
}
