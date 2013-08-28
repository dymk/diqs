module image_db.base_db;

/**
 * Represents an image database, held in memory and/or the disk.
 */

import types : user_id_t, coeffi_t;
import sig : ImageIdSigDcRes;
import consts : ImageArea, NumColorChans;

import std.algorithm : max;

interface BaseDb
{
	/**
	 * Inserts an image into the database. Returns the user ID  which is
	 * now associated with that image. If insetion fails, the function
	 * may throw.
	 */
	user_id_t addImage(in ImageIdSigDcRes);

	/**
	 * Removes an image with a given user ID from the database, returning
	 * the image if it was removed, or null if it failed. It may throw if
	 * the given ID wans't found in the database to begin with,
	 * or if removal failed for some reason.
	 */
	ImageIdSigDcRes* removeImage(user_id_t);
}

class IdGen(T)
{
	void saw(T id) {
		last_id = max(last_id, id+1);
	}

	T next() {
		return last_id++;
	}

private:
	T last_id;
}

unittest {
	auto id = new IdGen!uint();
	assert(id.next() == 0);
	assert(id.next() == 1);
}

unittest {
	auto id = new IdGen!uint();
	assert(id.next() == 0);
	id.saw(7);
	assert(id.next() == 8);
}

unittest {
	auto id = new IdGen!uint();
	assert(id.next() == 0);
	id.saw(0);
	assert(id.next() == 1);
}

unittest {
	auto id = new IdGen!uint();
	id.next();
	id.next();
	id.next();
	id.next();
	id.saw(2);
	assert(id.next() == 4);
}

unittest {
	auto id = new IdGen!uint();
	id.saw(10);
	assert(id.next() == 11);
	assert(id.next() == 12);
}
