module image_db.base_db;

/**
 * Represents an image database, held in memory and/or the disk.
 */

import types : user_id_t, coeffi_t;
import sig :
  ImageIdSigDcRes,
  ImageSigDcRes;
import consts : ImageArea, NumColorChans;
import query : QueryResult, QueryParams;

import std.conv : to;
import std.algorithm : max;

interface BaseDb
{
	static class BaseDbException : Exception {
		this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
	};
	static final class IdNotFoundException : BaseDbException {
		this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
		this(user_id_t id, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
		{ super("Image with ID " ~ to!string(id) ~ " not found in the database", file, line, next); }
	};
	static final class AlreadyHaveIdException : BaseDbException {
		this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
		this(user_id_t id, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
		{ super("Image with ID " ~ to!string(id) ~ " is already in the database", file, line, next); }
	};

	/**
	 * Inserts an image into the database. Returns the user ID  which is
	 * now associated with that image. If insetion fails, the function
	 * may throw.
	 */
	user_id_t addImage(in ImageIdSigDcRes);

	/**
	 * Inserts an image without a yet determind ID into the database
	 * and returns its assigned ID. The database will determine what
	 * ID to give the image.
	 */
	user_id_t addImage(in ImageSigDcRes);

	/**
	 * Removes an image with a given user ID from the database, returning
	 * the image if it was removed, or null if it failed. It may throw if
	 * the given ID wans't found in the database to begin with,
	 * or if removal failed for some reason.
	 */
	void removeImage(user_id_t);

	/**
	 * Returns the number of images in the database.
	 */
	uint numImages();

	/**
	 * Returns the next available user ID
	 */
	user_id_t peekNextId();

	/**
	 * Performs a query on the database
	 */
	QueryResult[] query(QueryParams);
}

// Guarenteed to never return the same number twice.
final class IdGen(T)
{
	synchronized void saw(T id) {
		last_id = max(last_id, id+1);
	}

	synchronized T next() {
		return last_id++;
	}

	synchronized T peek() {
		return last_id;
	}

private:
	T last_id;
}

unittest {
	scope id = new shared IdGen!uint();
	assert(id.next() == 0);
	assert(id.next() == 1);
}

unittest {
	scope id = new shared IdGen!uint();
	assert(id.next() == 0);
	id.saw(7);
	assert(id.next() == 8);
}

unittest {
	scope id = new shared IdGen!uint();
	assert(id.next() == 0);
	id.saw(0);
	assert(id.next() == 1);
}

unittest {
	scope id = new shared IdGen!uint();
	id.next();
	id.next();
	id.next();
	id.next();
	id.saw(2);
	assert(id.next() == 4);
}

unittest {
	scope id = new shared IdGen!uint();
	id.saw(10);
	assert(id.next() == 11);
	assert(id.next() == 12);
}

unittest {
	scope id = new shared IdGen!uint();
	assert(id.peek() == 0);
	assert(id.peek() == 0);
	assert(id.peek() == 0);
	assert(id.next() == 0);
	assert(id.peek() == 1);
	assert(id.next() == 1);
	id.saw(12);
	assert(id.peek() == 13);
}
