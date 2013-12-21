module image_db.persisted_db;

import image_db.base_db : BaseDb;
import image_db.mem_db : MemDb;
import sig;

import std.container : Array;
import std.range : isInputRange;

interface PersistedDb : BaseDb
{
	static class PersistedDbException : BaseDbException {
	  this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
	  { super(message, file, line, next); }
	};

	static final class DbNonexistantException : PersistedDbException {
	  this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
	  { super(message, file, line, next); }
	};

	// Generates a memory database from the persistance layer
	MemDb exportMemDb();

	// Flushes the data waiting to be persisted on whatever the persistence
	// media is.
	bool flush();

	// Returns true if there is data waiting to be flushed to the persistence
	// media.
	bool dirty();

	// Is the database closed?
	bool closed();

	// Close the database
	void close();

	// The path (or another unique string) representing the location of the
	// database
	string path() const;

	// A forward range to iterate over all the
	// images in the database.
	interface ImageDataIterator {
		ImageIdSigDcRes front();
		bool empty();
		void popFront();
	}
	static assert(isInputRange!ImageDataIterator);
	ImageDataIterator imageDataIterator();
}
