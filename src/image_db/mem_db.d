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
  ImageIdSigDcRes,
  ImageSigDcRes,
  ImageIdDcRes,
  ImageSig,
  ImageRes,
  ImageDc;
import query :
  QueryParams;

import std.algorithm : min, max;
import std.exception : enforce;

// TODO: DRY up custom exceptions

// Thrown when an image with an ID is inserted into the database, but
// the database already has an image with that ID
class AlreadyHaveIDException : Exception {
	this(string msg = "ID Already inserted in database", string file = __FILE__, size_t line = __LINE__)
	{ super(msg, file, line); }
}

// Thrown when an image that doesn't exist with a given ID is attempted to be retrieved or modified
class IDNotFoundException : Exception {
	this(string msg = "ID was not found in the database", string file = __FILE__, size_t line = __LINE__)
	{ super(msg, file, line); }
}

class MemDb : BaseDb
{
	alias StoredImage = ImageIdDcRes;

	/// Loads the database from the file in db_path
	this()
	{
		//m_user_mem_ids_map = new UserInternMap();
		m_manager = new BucketManager();
		m_id_gen = new IdGen!user_id_t;
	}

	/**
	 * Determine if the database holds an image with that user ID
	 * If it does, return a pointer to the image's information,
	 * else, return null.
	 */
	const StoredImage* has(user_id_t id)
	{
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
	const StoredImage* get(user_id_t id, bool throwOnNotFound = true)
	{
		auto img = has(id);
		if(img is null && throwOnNotFound) {
			throw new IDNotFoundException;
		}
		return img;
	}

	/**
	 * Adds an image onto the database. Multiple overloads
	 * so the user can choose to have an ID chosen for them,
	 * or explicitly specify the ID they'd like to refer to the
	 * image with.
	 */
	user_id_t addImage(in ImageSigDcRes img)
	{
		user_id_t user_id = m_id_gen.next();
		addImage(img, user_id);
		return user_id;
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
		m_mem_imgs[intern_id] = StoredImage(user_id, img.dc, img.res);

		id_intern_map[user_id] = intern_id;

		m_manager.addSig(intern_id, img.sig);

		// Arbitrary limit so the user can't have more than 4B
		// images in the database (and they don't overflow
		// internal IDs).
		enforce(m_mem_imgs.length <= intern_id_t.max);

		return true;
	}

	/**
	 * Removes an image
	 * TODO: Figure out a better thing to return in this function
	 * Should it return a pointer to the image somewhere in the heap?
	 */
	ImageIdSigDcRes* removeImage(user_id_t user_id, bool throwOnDidntHave = true)
	{
		// Map to the internal ID
		auto maybe_rm_id = user_id in id_intern_map;
		if(maybe_rm_id is null)
		{
			if(throwOnDidntHave) {
				throw new IDNotFoundException;
			}
			else {
				return null;
			}
		}

		immutable auto rm_intern_id = *maybe_rm_id;
		immutable auto rm_image     = m_mem_imgs[rm_intern_id];

		ImageSig sig = m_manager.removeId(rm_intern_id);

		auto ret = new ImageIdSigDcRes;
		ret.sig = sig;
		ret.dc = rm_image.dc;
		ret.res = rm_image.res;

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
			//m_manager.moveId(last_intern_id, rm_intern_id);
		}

		m_mem_imgs.length--;

		return ret;
	}

	auto numImages() @property { return m_mem_imgs.length; }

	auto query(const QueryParams params)
	{
		return params.perform(m_manager, m_mem_imgs);
	}

private:
	// Maps a user_id to its index in m_mem_imgs
	//scope immutable(StoredImage)[] m_mem_imgs;
	scope StoredImage[] m_mem_imgs;

	// Maps immutable user IDs to internal IDs
	scope intern_id_t[user_id_t] id_intern_map;

	scope BucketManager m_manager;

	scope IdGen!user_id_t m_id_gen;
}

version(unittest)
{
	static immutable ImageSigDcRes img;
	static immutable ImageSigDcRes img2;
	static this() {
		img = ImageSigDcRes.fromFile("test/cat_a1.jpg");
		img2 = ImageSigDcRes.fromFile("test/cat_a2.jpg");
	}
}

unittest {
	assert(img.sig.sameAs(img2.sig) == false);
	assert(img.dc != img2.dc);
	assert(img.res != img2.res);
}

unittest {
	auto db = new MemDb();
	assert(db.numImages() == 0);

	db.addImage(img);

	assert(db.numImages() == 1);
}

unittest {
	auto db = new MemDb();
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
	db.addImage(img, 0);

	bool thrown = false;
	assert(db.get(1, false) is null);
}

unittest {
	auto db = new MemDb();
	auto id = db.addImage(img);
	// This doesn't actually need to pass; the
	// unittest is here to show that addImage
	// without an ID returns all the image data.
	assert(id == 0);
}

unittest {
	auto db = new MemDb();
	auto id = db.addImage(img);
	assert((*db.removeImage(id)).sig.sameAs(img.sig));
}

unittest {
	auto db = new MemDb();
	bool thrown = false;
	try
	{
		db.removeImage(0);
	}
	catch(IDNotFoundException e)
	{
		thrown = true;
	}
	assert(thrown);
}

unittest {
	auto db = new MemDb;
	auto ret = db.removeImage(0, false);
	assert(ret is null);
}

unittest {
	auto db = new MemDb;

	auto id = db.addImage(img);
	db.removeImage(id);

	assert(db.has(id) == null);
	assert(db.numImages() == 0);
}

unittest {
	auto db = new MemDb;
	auto id = db.addImage(img);
	assert(id == db.get(id).user_id);
}

unittest {
	auto db = new MemDb;
	auto id = 897654;
	db.addImage(img, id);
	assert(id == db.get(id).user_id);
}

unittest {
	auto db = new MemDb;
	auto id1 = 32817;
	db.addImage(img, id1);
	auto id2 = 857436;
	db.addImage(img2, id2);

	assert(db.numImages() == 2);

	assert(db.get(id1).dc == img.dc);
	assert(db.get(id1).res == img.res);

	assert(db.get(id2).dc == img2.dc);
	assert(db.get(id2).res == img2.res);

	assert(db.has(id1));
	assert(db.has(id2));

	auto rm_img1 = db.removeImage(id1);
	assert(db.numImages() == 1);

	// Verify the right image is returned from remove
	assert(rm_img1.sig.sameAs(img.sig));
	assert(rm_img1.dc == img.dc);
	assert(rm_img1.res == img.res);

	assert(!db.has(id1));
	assert(db.has(id2));

	auto rm_img2 = db.removeImage(id2);
	assert(!db.has(id2));
	assert(db.numImages() == 0);

	assert(rm_img2.sig.sameAs(img2.sig));
	assert(rm_img2.dc == img2.dc);
	assert(rm_img2.res == img2.res);

	import std.stdio;
}
