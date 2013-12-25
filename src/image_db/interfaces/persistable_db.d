module image_db.interfaces.persistable_db;

import image_db.all;
import sig;

import std.container : Array;
import std.range : isInputRange;

interface PersistableDb
{
	static class PersistableDbException : BaseDb.BaseDbException {
	  this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
	  { super(message, file, line, next); }
	};

	static final class DbNonexistantException : PersistableDbException {
	  this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
	  { super(message, file, line, next); }
	};

	// Useful for when batch image insertions need to happen
	// Closes/opens an owned memory database
	void destroyQueryable();
	void makeQueryable();

	// Flushes the data waiting to be persisted on whatever the persistence
	// media is.
	bool flush();

	// Is the database closed?
	bool closed();

	// Close the database
	void close();

	// The path (or another unique string) representing the location of the
	// database
	string path() const;

	// Is the database, with respect to the persistence medium, clean/dirty?
	bool dirty();

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
