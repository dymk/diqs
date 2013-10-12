module image_db.file_db;

/**
 * Represents an image database that can syncronize with the disk.
 */

import std.typecons : Tuple;
import std.exception : enforce, enforceEx;
import std.container : Array;
import core.memory : GC;
import core.sync.mutex : Mutex;

import std.stdio : File, writeln;
//import vibe.core.file :
//  existsFile,
//  openFile,
//  FileMode,
//  FileStream;

import persistence_layer.file_helpers;
import types :
  user_id_t,
  intern_id_t,
  coeffi_t,
  sig_t,
  chan_t;

import sig :
  ImageIdSigDcRes,
  ImageSigDcRes,
  ImageSig,
  ImageRes,
  ImageDc;

import image_db.bucket_manager : BucketManager, BucketSizes;
import image_db.base_db        : BaseDb, IdGen;
import image_db.persisted_db   : PersistedDb;
import image_db.mem_db         : MemDb;
import consts :
  ImageArea,
  NumColorChans,
  NumBuckets;

import query :
  QueryResult,
  QueryParams;

final class FileDb : PersistedDb
{
	static class FileDbException : Exception {
		this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
	};
	static final class InvalidFileException : FileDbException {
		this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
	};
	static final class DbFileNotFoundException : FileDbException {
		this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
	};
	static final class DbFileAlreadyExistsException : FileDbException {
		this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
	};
	static final class DbDirtyException : FileDbException {
		this(string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super("Database is dirty", file, line, next); }
		this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
	};
	// Thrown if the underlying MemDb has already been released
	static final class AlreadyReleasedException : FileDbException {
		this(string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super("Database already loaded", file, line, next); }
		this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
	};
	static final class DbClosedException : FileDbException {
		this(string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super("Database is closed", file, line, next); }
		this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
	};

	enum ulong Magic       = 0xDEADBEEF;
	enum OffsetMagic       = 0;
	enum OffsetNumImages   = ulong.sizeof;
	enum OffsetBucketSizes = OffsetNumImages + uint.sizeof;
	enum OffsetImageData   = OffsetBucketSizes + (uint.sizeof * NumBuckets);

	/**
	 * Creates a database at path 'path'. If the Db already exists,
	 * a DbFileAlreadyExistsException is thrown.
	 */
	static FileDb createFromFile(string path)
	{
		if(existsFile(path)) {
			throw new DbFileAlreadyExistsException(path);
		}
		return loadFromFile(path, true);
	}

	/**
	 * Loads the db file at 'path'. Throws if it doesn't exist, unless
	 * create_if_nonexistant is true, in which case a blank database is created.
	 */
	static FileDb loadFromFile(string path, bool create_if_nonexistant = false)
	{
		return new FileDb(path, create_if_nonexistant);
	}

	/**
	 * Adds an image to the database, and returns the image's user ID.
	 * By default, the database is flushed to the disk after the operation
	 * completes.
	 */
	user_id_t addImage(in ImageIdSigDcRes img, bool flush_now) {
		enforceOpened();
		auto ret = enforceMemDb().addImage(img);
		m_add_jobs.insertBack(img);

		if(flush_now)
			flush();
		return ret;
	}
	user_id_t addImage(in ImageIdSigDcRes img) {
		return addImage(img, true);
	}

	/**
	 * Removes an image from the database, and returns that image.
	 * By default, the database is flushed to the disk after the operation
	 * completes.
	 */
	ImageIdSigDcRes removeImage(user_id_t user_id, bool flush_now) {
		enforceOpened();
		auto ret = enforceMemDb().removeImage(user_id);
		m_rm_jobs.insertBack(user_id);

		if(flush_now)
			flush();
		return ret;
	}
	ImageIdSigDcRes removeImage(user_id_t user_id) {
		return removeImage(user_id, true);
	}

	// By default, force the DB to be clean before closing it
	void close() { close(true); }
	void close(bool enforce_clean) {

		//synchronized(m_handle_mutex) {

			if(enforce_clean) {
				enforceClean();
			} else {
				enforceOpened();
			}

			m_handle.close();
			m_closed = true;

			if(m_mem_db !is null) {
				m_mem_db.destroy();
				GC.free(cast(void*)m_mem_db);
				m_mem_db = null;
			}
		//}
	}

	bool opened() { return !closed(); }
	bool closed() {
		//synchronized(m_handle_mutex) {
			return m_closed;
		//}
	}

	bool clean() { return !dirty(); }
	bool dirty() {
		return m_add_jobs.length || m_rm_jobs.length;
	}

	user_id_t peekNextId() {
		return enforceMemDb().peekNextId();
	}

	/**
	 * Perform a query on the database.
	 * if allow_dirty is true, then the query is performed
	 * on the underlying db, and a check that the file DB has
	 * been flushed ot the disk is skipped.
	 *
	 * By default, the database must be clean in order to perform
	 * a query.
	 */
	QueryResult[] query(QueryParams params, bool allow_dirty)
	{
		if(!allow_dirty)
			enforceClean();
		return enforceMemDb().query(params);
	}
	QueryResult[] query(QueryParams params) {
		return query(params, false);
	}

	/*
	 * Returns an InputRange which iterates over
	 * all the images on the disk. Requires the database
	 * to be open and clean.
	 */
	FileImageDataIterator imageDataIterator() {
		return new FileImageDataIterator;
	}

	/**
	 * Returns the file path to the database.
	 */
	string path() {
		return m_path;
	}

	/**
	 * Returns the number of images in the underlying memdb.
	 * By default, the database must be clean. This can be
	 * overridden by calling numImages(true), which skips
	 * the database clean check.
	 *
	 * Note that if the clean check is skipped, the number of
	 * images returned will reflect the number at the last flush,
	 * not the number waiting to be written/removed from the disk.
	 */
	uint numImages() {
		return numImages(false);
	}
	uint numImages(bool allow_dirty) {
		if(!allow_dirty)
			enforceClean();
		return enforceMemDb().numImages();
	}

	bool released() {
		return m_mem_db !is null;
	}

	MemDb releaseMemDb() {
		MemDb ret = enforceMemDb();
		m_mem_db = null;
		close();
		return ret;
	}

	bool flush() {
		// Flushes the queued jobs add/remove image jobs to the disk
		enforceOpened();

		// we need an exclusive lock on the file to do work
		m_handle_mutex.lock();
		scope(exit) { m_handle_mutex.unlock(); }

		foreach(rm_id; m_rm_jobs) {
			if(m_add_jobs.length) {
				auto replacement_image = m_add_jobs.removeAny();
				fileReplaceImage(rm_id, replacement_image);
			} else {
				fileRemoveImage(rm_id);
			}
		}

		foreach(image; m_add_jobs) {
			fileAppendImage(image);
		}

		m_rm_jobs.clear();
		m_add_jobs.clear();

		// Write the header information (number of images + bucket size metadata)
		m_handle.seek(OffsetNumImages);
		m_handle.writeUint(numImages());

		m_handle.seek(OffsetBucketSizes);
		foreach(size; m_bucket_sizes.sizes) {
			m_handle.writeUint(size);
		}

		m_handle.flush();
		return true;
	}

private:
	final class FileImageDataIterator : ImageDataIterator {

		this() {
			enforceOpened();
			enforceClean();
		}

		ImageIdSigDcRes front()
		in {
			assert(!empty());
		}
		body {
			return readImageDataAtIndex(m_pos);
		}

		void popFront()
		in {
			assert(!empty());
		}
		body {
			m_pos++;
		}

		bool empty()
		out(ret) {
			if(ret == true) {
				assert(m_pos == m_num_images);
			} else {
				assert(m_pos < m_num_images);
				assert(!m_handle.eof());
			}
		}
		body {
			return m_pos >= m_num_images;
		}

	private:
		uint m_pos;
	}

	~this() {
		writeln("Destroying filedb");
		if(opened()) {
			writeln("was open, closing filedb");
			close();
		}
	}

	this(string path, bool create_if_nonexistant)
	{
		if(!existsFile(path))
		{
			if(create_if_nonexistant) {

				m_handle = File(path, "wb+");
				writeBlankDbToStream(m_handle);
			}
			else
			{
				throw new DbFileNotFoundException(path);
			}
		}
		else
		{
			m_handle = File(path, "rb+");
		}

		// Will be useful when m_handle is a class
		// m_handle_mutex = new Mutex(cast(Object)m_handle);
		m_handle_mutex = new Mutex();

		m_mem_db = new MemDb();
		m_bucket_sizes = new BucketSizes();

		m_path = path;

		load();
	}

	void load() {
		m_handle.seek(OffsetMagic);
		enforceEx!InvalidFileException(m_handle.readUlong() == Magic,
			"FileDb header is invalid");

		m_handle.seek(OffsetNumImages);
		m_num_images = m_handle.readUint();

		enforce(m_handle.tell() == OffsetBucketSizes);

		foreach(ref uint size; m_bucket_sizes.sizes) {
			size = m_handle.readUint();
		}

		m_mem_db.bucketSizeHint(m_bucket_sizes);

		enforce(m_handle.tell() == OffsetImageData);

		uint index = 0;
		scope itr = imageDataIterator();
		foreach(ref ImageIdSigDcRes image_data; itr) {
			m_mem_db.addImage(image_data);
			m_id_index_map[image_data.user_id] = index;
			index++;
		}
	}

	void enforceClean() {
		enforceEx!DbDirtyException(clean());
	}

	void enforceOpened() {
		enforceEx!DbClosedException(opened());
	}

	MemDb enforceMemDb() {
		return enforceEx!AlreadyReleasedException(m_mem_db);
	}


	// For now, use blocking file I/O due to vibe being buggy.
	File m_handle;
	Mutex m_handle_mutex;
	string m_path;
	bool m_closed = false;

	// Underlying memory database
	MemDb m_mem_db;

	// Bookeeping for the database
	BucketSizes* m_bucket_sizes;
	uint m_num_images;

	alias ImageAddJob = ImageIdSigDcRes;
	alias ImageRmJob  = user_id_t;

	// Add/Remove batch jobs
	Array!ImageAddJob m_add_jobs;
	Array!ImageRmJob  m_rm_jobs;

	// Maps a user_id_t to the actual index/position on the disk.
	uint[user_id_t] m_id_index_map;


	/**
	 * File specific operations
	 */
	int enforceHasImage(user_id_t user_id) {
		auto loc = user_id in m_id_index_map;
		if(loc is null) {
			throw new BaseDb.IdNotFoundException(user_id);
		}
		return *loc;
	}


	ImageIdSigDcRes fileReplaceImage(user_id_t rm_id, ImageIdSigDcRes replacement) {
		auto loc = enforceHasImage(rm_id);
		auto ret = fileReadImageAtIndex(loc);

		m_id_index_map.remove(rm_id);
		fileWriteImageAtIndex(loc, replacement);

		return ret;
	}

	ImageIdSigDcRes fileRemoveImage(user_id_t rm_id) {
		auto ret = fileReplaceImage(rm_id, fileReadImageAtIndex(m_num_images-1));

		m_id_index_map.remove(rm_id);

		subFromBucketSizes(ret.sig);
		m_num_images--;

		return ret;
	}

	//ImageIdSigDcRes fileReadImage(user_id_t user_id) {
	//	auto loc = enforceHasImage(user_id);
	//	return fileReadImageAtIndex(loc);
	//}

	ImageIdSigDcRes fileReadImageAtIndex(uint index) {
		enforce(index < m_num_images);

		synchronized(m_handle_mutex) {
			seekHandleToImageDataIndex(m_handle, index);
			return m_handle.readValue!ImageIdSigDcRes();
		}
	}

	void fileWriteImageAtIndex(uint index, ImageIdSigDcRes image) {
		enforce(index <= m_num_images); // Allow at m_num_images so the file can be appended to

		synchronized(m_handle_mutex) {
			seekHandleToImageDataIndex(m_handle, index);
			m_handle.writeValue!ImageIdSigDcRes(image);
		}

		m_id_index_map[image.user_id] = index;
	}

	void fileAppendImage(ImageIdSigDcRes image) {
		if(image.user_id in m_id_index_map) {
			throw new BaseDb.AlreadyHaveIdException(image.user_id);
		}

		fileWriteImageAtIndex(m_num_images, image);

		addToBucketSizes(image.sig);
		m_num_images++;
	}

	ImageIdSigDcRes readImageDataAtIndex(uint index)
	{
		synchronized(m_handle_mutex) {
			seekHandleToImageDataIndex(m_handle, index);
			return m_handle.readValue!ImageIdSigDcRes();
		}
	}

	/**
	 * Bucket size specific functions
	 */
	void addToBucketSizes(ImageSig sig) {
		opFromBucketSizes!("++")(sig);
	}

	void subFromBucketSizes(ImageSig sig) {
		opFromBucketSizes!("--")(sig);
	}

	void opFromBucketSizes(alias string op)(ImageSig image_sig)
	if(op == "++" || op == "--")
	{
		foreach(ubyte chan, ref sig_t sig; image_sig.sigs) {

			auto chan_sizes = m_bucket_sizes.forChan(chan);
			foreach(coeffi_t coeff; sig)
			{
				ushort index = BucketManager.bucketIndexForCoeff(coeff);
				mixin("chan_sizes[index]" ~ op ~ ";");
			}
		}
	}
}

/**
 * Writes a blank database file to the handle. Optionally checks that the file
 * is empty before performing the overwrite.
 */
private void writeBlankDbToStream(Stream)(Stream handle, bool enforce_empty = true) {
	if(enforce_empty) {
		enforce(handle.size() == 0);
	}

	handle.seek(0);
	handle.writeUlong(FileDb.Magic);

	enforce(handle.tell() == FileDb.OffsetNumImages);
	handle.writeUint(0);

	enforce(handle.tell() == FileDb.OffsetBucketSizes);
	foreach(i; 0..NumBuckets) {
		handle.writeUint(0);
	}

	enforce(handle.tell() == FileDb.OffsetImageData);

	handle.flush();
	handle.seek(0);
}

/**
 * Seeks the handle to the position of the image data at 'index'.
 */
private void seekHandleToImageDataIndex(Stream)(Stream handle, uint index) {
	handle.seek(FileDb.OffsetImageData + (index * ImageIdSigDcRes.sizeof));
}
