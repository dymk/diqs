module image_db.base_db;

/**
 * Represents an image database, held in memory and/or the disk.
 */

import types : user_id_t, coeffi_t;
import sig :
  ImageIdSigDcRes,
  ImageSigDcRes;
import consts : ImageArea, NumColorChans;

import std.conv : to;
import std.algorithm : max;

interface BaseDb
{
	static class BaseDbException : Exception {
		this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
	};
	static final class IdNotFoundException : BaseDbException {
		this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
		this(user_id_t id, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super("Image with ID " ~ to!string(id) ~ " not found in the database", file, line, next); }
	};
	static final class AlreadyHaveIdException : BaseDbException {
		this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
		this(user_id_t id, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super("Image with ID " ~ to!string(id) ~ " is already in the database", file, line, next); }
	};

	/**
	 * Inserts an image into the database. Returns the user ID  which is
	 * now associated with that image. If insetion fails, the function
	 * may throw.
	 */
	user_id_t addImage(in ImageIdSigDcRes);

	final user_id_t addImage(in ImageSigDcRes img, user_id_t user_id) {
		ImageIdSigDcRes id_img = ImageIdSigDcRes(user_id, img.sig, img.dc, img.res);
		return addImage(id_img);
	}

	/**
	 * This version does the same as the previous, but the database
	 * implementation will decide on the user_id to assign to the
	 * image.
	 *
	 * Not implemented yet, because I'm not sure if I want to delegate
	 * selection to outside of the database implementations.
	 */
	//user_id_t addImage(in ImageSigDcRes);

	/**
	 * Removes an image with a given user ID from the database, returning
	 * the image if it was removed, or null if it failed. It may throw if
	 * the given ID wans't found in the database to begin with,
	 * or if removal failed for some reason.
	 */
	ImageIdSigDcRes removeImage(user_id_t);

	/**
	 * Returns the number of images in the database.
	 */
	uint numImages();

	user_id_t nextId();
}

// Guarenteed to never return the same number twice.
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
