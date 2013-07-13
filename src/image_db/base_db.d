module image_db.base_db;

/**
 * Represents an image database, held in memory and/or the disk.
 */

import types : user_id_t;
import sig : ImageData, IDImageData;

abstract class BaseDB
{
	IDImageData addImage(ImageData);

	/// Returns the next unique ID for an image
	/// User facing IDs are not expected to be
	/// continuous; there's an internal ID which can
	/// be changed on image removal.
	protected user_id_t nextUserId()
	{
		return m_next_user_id++;
	}

private:
	// The next highest user facing ID in the database (highest found + 1)
	user_id_t m_next_user_id = 0;
}

version(unittest) {
	// Stub to test BaseDB methods
	class TestDB : BaseDB
	{
		override IDImageData addImage(ImageData i) { throw new Exception("stub"); }
	}
}

unittest {
	auto f = new TestDB();
	assert(f.nextUserId() == 0);
	assert(f.nextUserId() == 1);
	assert(f.nextUserId() == 2);
}
