module image_db.persisted_db;

import image_db.base_db : BaseDb;
import image_db.mem_db : MemDb;
import sig;

import std.container : Array;
import std.range : isInputRange;

interface PersistedDb : BaseDb
{
	// Releases the underlying MemDb. Invalidates the database from.
	MemDb releaseMemDb();

	// Returns true if the memdb has already been released.
	bool released();

	// Flushes the data waiting to be persisted on whatever the persistence
	// media is.
	bool flush();

	// Returns true if there is data waiting to be flushed to the persistence
	// media.
	bool dirty();
	bool clean(); // !dirty()

	// Is the database closed?
	bool closed();
	bool opened(); // !closed()

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
