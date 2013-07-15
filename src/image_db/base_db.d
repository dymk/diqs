module image_db.base_db;

/**
 * Represents an image database, held in memory and/or the disk.
 */

import types : user_id_t;
import sig : ImageData, IDImageData;

abstract class BaseDB
{
	IDImageData addImage(ImageData);

	/**
	 * Returns the next unique ID for an image. User facing IDs are not expected
	 * to be continuous; there's an internal ID which can be changed on image
	 * removal.
	 */
	protected user_id_t nextUserId()
	{
		return m_next_user_id++;
	}

	short bucketIndexForCoeff(coeffi_t coeff)
	{
		assert(coeff != 0, "Coeff at 0 is a DC component; not a sig coeff");
		// Because there is no 0 bucket, shift
		// all bucekts > 0 down by 1
		if(coeff > 0)
			coeff--;
		coeff += ImageArea; // Eg bucket -16384 => 0
		return coeff;
	}

	/// Inverse of bucketIndexForCoeff
	/// Convert a bucket's index to a coefficient
	/// EG 0 => -16384
	coeffi_t coeffForBucketIndex(short index)
	{
		if(index >= ImageArea)
			index++;
		index -= ImageArea;
		return index;
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
