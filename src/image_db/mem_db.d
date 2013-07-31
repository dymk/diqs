module image_db.mem_db;

/**
 * Represents an in memory, searchable database of images
 */

import image_db.bucket_manager : BucketManager;
import image_db.base_db : BaseDB;
import types :
  user_id_t,
  intern_id_t;
import sig :
	ImageDC,
	ImageRes,
	ImageData,
	IDImageData;

import dcollections.HashMap : HashMap;

class MemDB : BaseDB
{
	//alias UserInternMap = HashMap!(user_id_t, intern_id_t);

	struct IDImageSansSig
	{
		user_id_t user_id;
		ImageDC dc;
		ImageRes res;
	}

	/// Loads the database from the file in db_path
	this()
	{
		//m_user_mem_ids_map = new UserInternMap();
		m_manager = new BucketManager();
	}

	IDImageData addImage(const ref ImageData imgdata)
	{
		//immutable user_id = nextUserId();
		immutable sig = imgdata.sig;
		immutable dc = imgdata.dc;
		immutable res = imgdata.res;

		// Next ID is just the next available spot in the in-mem array
		immutable user_id_t user_id = m_mem_imgs.length;

		immutable img = IDImageData(user_id, sig, dc, res);

		/* 	We're skipping any sort of optimization for image
		removal; that's planned for the future */
		// Append the image's DC onto the memory array of DC data
		// and record its position in the array
		//enforce(m_user_mem_ids_map.elemAt(user_id).empty,
		//	"Image with that ID is already held in memory!");
		//intern_id_t intern_id = m_mem_imgs.length;
		//m_user_mem_ids_map[user_id] = intern_id;

		m_mem_imgs ~= IDImageSansSig(user_id, dc, res);
		m_manager.addSig(user_id, sig);

		return img;
	}

	auto numImages() @property { return m_mem_imgs.length; }

private:
	// Maps a user_id to its index in m_mem_imgs
	//scope UserInternMap m_user_mem_ids_map;
	scope IDImageSansSig[] m_mem_imgs;

	scope BucketManager m_manager;
}

unittest {
	auto db = new MemDB();
	assert(db.numImages() == 0);

	auto sig = ImageData.fromFile("test/cat_a1.jpg");
	db.addImage(sig);

	assert(db.numImages() == 1);
}
