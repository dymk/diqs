module image_db.persisted_db;

abstract class PersistedDb
{
	// Performs the actual loading of the database into memory,
	// and generation of whatever other bookkeeping information it needs
	void load();

	// Releases the underlying MemDb. Invalidates the database.
	MemDb release();

	// Returns true if the database can be queried
	bool canQuery();

	// Returns true if the database can be flushed
	// to the underlying persisted layer.
	bool canFlush();

	// Returns true if the flush queue isn't empty.
	bool dirty();

	// Writes the add queue to the persistence medium.
	final bool flush() {
		bool ret = m_add_jobs.length || m_remove_jobs.length;
		flushQueue(m_add_jobs, m_remove_jobs);

		m_add_jobs.clear();
		m_remove_jobs.clear();

		return ret;
	}

	final auto addImage(in ImageIdSigDcRes img) {
		auto ret = borrowMemDb().addImage(img);
		onImageAdded(img);
		m_add_jobs.insertBack(img);
		return ret;
	}

	final auto removeImage(user_id_t user_id) {
		auto ret = borrowMemDb().removeImage(user_id);
		onImageRemoved(user_id);
		m_remove_jobs.insertBack(user_id);
		return ret;
	}

	// A forward range to iterate over all the
	// images in the database.
	interface ImageDataIterator {
		ImageIdSigDcRes front();
		void popFront();
		bool empty();
	}
	ImageDataIterator imageDataIterator();

	~this() {
		m_add_jobs.clear();
		m_remove_jobs.clear();
		GC.free(mem_db);
	}

protected:
	void flushQueue(AddImageJobs[], RemoveImageJobs[]);
	MemDb borrowMemDb();

	// Optional methods for subclasses to implement. Called on
	// image adding or removal.
	void onImageAdded(in ImageIdSigDcRes) {};
	void onImageRemoved(user_id_t)        {};

	this() {
		mem_db = new MemDb();
	}

private:
	alias ImageAddJob = ImageIdSigDcRes;
	alias ImageRmJob  = user_id_t;

	Array!ImageAddJob m_add_jobs;
	Array!ImageRmJob  m_rm_jobs;

	MemDb mem_db;
}
