module persistance_layer.on_disk_persistance;

import std.stdio : File;
import std.conv : to;
import std.container : Array;
import std.file : exists;
import std.exception : enforce, enforceEx;

import persistance_layer.persistance_layer : PersistanceLayer;
import persistance_layer.file_helpers;

import sig :
	ImageIdSigDcRes,
  ImageSig;

import types :
  intern_id_t,
  user_id_t,
  coeffi_t,
  sig_t;

import consts :
  NumColorChans,
  NumSigCoeffs,
  NumBuckets;

import image_db.bucket_manager :
  BucketManager,
  BucketSizes;

import image_db.base_db : BaseDb;

// TODO: Allow lazy execution of syncImageLocations(). It would be
// nice for massive databases to not have to be scanned more than
// one time on startup.

class OnDiskPersistance : PersistanceLayer
{
	static class OnDiskPersistanceException : Exception {
		this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
	};

	static class InvalidFileException : OnDiskPersistanceException {
		this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
	};
	static class DatabaseNotFoundException : OnDiskPersistanceException {
		this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
	};
	static class DatabaseDirtyException : OnDiskPersistanceException {
		this(string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super("Database is dirty", file, line, next); }
		this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
	};

	enum ulong Magic       = 0xDEADBEEF;
	enum OffsetMagic       = 0;
	enum OffsetNumImages   = ulong.sizeof;
	enum OffsetBucketSizes = OffsetNumImages + uint.sizeof;
	enum OffsetImageData   = OffsetBucketSizes + (uint.sizeof * NumBuckets);

	static OnDiskPersistance fromFile(string file_path, bool create_if_nonexistant = false)
	{
		File db_file;

		if(!exists(file_path)) {

			if(create_if_nonexistant)
			{
				db_file = File(file_path, "wb+");
				writeBlankDbFile(db_file);
			}
			else
			{
				throw new DatabaseNotFoundException("Database '" ~ file_path ~ "' does not exist");
			}
		}
		else
		{
			db_file = File(file_path, "rb+"); // Opens for reading/writing (doens't truncate file)
		}

		return new OnDiskPersistance(db_file);
	}

	BucketSizes* bucketSizes() {
		enforceEx!DatabaseDirtyException(!dirty);
		return m_bucket_sizes;
	}

	ImageIdSigDcRes getImage(user_id_t user_id) {
		enforceEx!DatabaseDirtyException(!dirty);

		auto loc = enforceHasImage(user_id);
		return fileReadImageAtIndex(loc);
	}

	ImageIdSigDcRes removeImage(user_id_t user_id) {
		auto loc = enforceHasImage(user_id);
		m_rm_jobs.insertBack(user_id);
		return fileReadImageAtIndex(loc);
	}

	void appendImage(ImageIdSigDcRes image) {
		m_add_jobs.insertBack(image);
	}

	uint length() {
		enforceEx!DatabaseDirtyException(!dirty);
		return m_num_images;
	}

	void save() {
		syncImageData();
		syncHeaders();
	}

	bool dirty() @property {
		return m_rm_jobs.length || m_add_jobs.length;
	}

	ImageDataIterator imageDataIterator() {
		return new OnDiskImageIterator;
	}

	class OnDiskImageIterator : ImageDataIterator {
		this() {
			enforceEx!DatabaseDirtyException(!dirty);
		}

		ImageIdSigDcRes front() {
			fileSeekToImageIndex(cur_pos);
			return m_db_file.readValue!ImageIdSigDcRes();
		}

		void popFront() {
			cur_pos++;
		}

		bool empty() {
			enforceEx!DatabaseDirtyException(!dirty);
			return cur_pos == m_num_images;
		}

	private:
		uint cur_pos = 0;
	}

	void close() {
		m_db_file.close();
	}

	bool hasValidHeaders() {
		m_db_file.seek(OffsetMagic);
		if(m_db_file.readUlong() != Magic)
			return false;

		return true;
	}

private:

	this(File db_file)
	{
		this.m_db_file = db_file;

		m_db_file.seek(OffsetMagic);
		enforce(m_db_file.tell() == OffsetMagic);
		ulong magic = m_db_file.readUlong();
		if(magic != Magic) {
			throw new InvalidFileException("Magic for DB was " ~ to!string(magic) ~ " instead of expected " ~ to!string(Magic));
		}

		enforce(m_db_file.tell() == OffsetNumImages);
		this.m_num_images = m_db_file.readUint();

		enforce(m_db_file.tell() == OffsetBucketSizes);
		BucketSizes* bucket_sizes = new BucketSizes;
		foreach(ref int bucket_size; bucket_sizes.sizes)
		{

			if(m_db_file.eof()) {
				throw new InvalidFileException("Database ended short of reading all bucket sizes.");
			}

			uint size = m_db_file.readUint();
			enforce(size <= int.max);
			bucket_size = cast(int) size;
		}
		this.m_bucket_sizes = bucket_sizes;
		enforce(m_db_file.tell() == OffsetImageData);

		syncImageLocations();
	}

	void syncImageLocations() {
		enforceEx!DatabaseDirtyException(!dirty);

		auto itr = imageDataIterator();
		int index = 0;
		foreach(img; imageDataIterator()) {
			m_ids_file_map[img.user_id] = index;
			index++;
		}
		//writeln("Mapped images: ")
	}

	int enforceHasImage(user_id_t user_id) {
		auto loc = user_id in m_ids_file_map;
		if(loc is null) {
			throw new BaseDb.IdNotFoundException(user_id);
		}
		return *loc;
	}


	ImageIdSigDcRes fileReplaceImage(user_id_t rm_id, ImageIdSigDcRes replacement) {
		auto loc = enforceHasImage(rm_id);
		auto ret = fileReadImageAtIndex(loc);

		m_ids_file_map.remove(rm_id);
		fileWriteImageAtIndex(loc, replacement);

		return ret;
	}

	ImageIdSigDcRes fileRemoveImage(user_id_t rm_id) {
		auto ret = fileReplaceImage(rm_id, fileReadImageAtIndex(m_num_images-1));

		m_ids_file_map.remove(rm_id);

		subFromBucketSizes(ret.sig);
		m_num_images--;

		return ret;
	}

	ImageIdSigDcRes fileReadImage(user_id_t user_id) {
		auto loc = enforceHasImage(user_id);
		return fileReadImageAtIndex(loc);
	}

	ImageIdSigDcRes fileReadImageAtIndex(uint index) {
		enforce(index < m_num_images);
		fileSeekToImageIndex(index);
		return m_db_file.readValue!ImageIdSigDcRes();
	}

	void fileWriteImageAtIndex(uint index, ImageIdSigDcRes image) {
		enforce(index <= m_num_images); // Allow at m_num_images so the file can be appended to
		fileSeekToImageIndex(index);
		m_db_file.writeValue!ImageIdSigDcRes(image);

		m_ids_file_map[image.user_id] = index;
	}

	void fileAppendImage(ImageIdSigDcRes image) {
		if(image.user_id in m_ids_file_map) {
			throw new BaseDb.AlreadyHaveIdException(image.user_id);
		}

		fileWriteImageAtIndex(m_num_images, image);

		addToBucketSizes(image.sig);
		m_num_images++;
	}

	void fileSeekToImageIndex(uint index) {
		m_db_file.seek(OffsetImageData + (index * ImageIdSigDcRes.sizeof));
	}

	void syncImageData() {
		// Writes the add/remove queue to the disk
		foreach(rm_id; m_rm_jobs) {
			if(m_add_jobs.length) {
				auto replacementImage = m_add_jobs.removeAny();
				fileReplaceImage(rm_id, replacementImage);
			} else {
				fileRemoveImage(rm_id);
			}
		}
		m_rm_jobs.clear();

		foreach(image; m_add_jobs) {
			fileAppendImage(image);
		}

		m_add_jobs.clear();
		m_db_file.flush();
	}

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

			int[] chan_sizes = m_bucket_sizes.forChan(chan);
			foreach(coeffi_t coeff; sig)
			{
				ushort index = BucketManager.bucketIndexForCoeff(coeff);
				mixin("chan_sizes[index]" ~ op ~ ";");
			}
		}
	}

	void syncHeaders() {
		enforceEx!DatabaseDirtyException(!dirty);

		m_db_file.seek(OffsetMagic);
		m_db_file.writeUlong(Magic);

		enforce(m_db_file.tell() == OffsetNumImages);
		m_db_file.writeUint(m_num_images);

		enforce(m_db_file.tell() == OffsetBucketSizes);
		foreach(bucket_size; m_bucket_sizes.sizes)
		{
			m_db_file.writeUint(bucket_size);
		}

		enforce(m_db_file.tell() == OffsetImageData);
		m_db_file.flush();
	}

	~this() {
		save();
		close();
	}

	alias ImageAddJob = ImageIdSigDcRes;
	alias ImageRmJob  = user_id_t;

	Array!ImageAddJob m_add_jobs;
	Array!ImageRmJob  m_rm_jobs;

	uint m_num_images;
	scope BucketSizes* m_bucket_sizes;
	File m_db_file;

	// Maps a user_it_t to where the image exists on
	// the disk itself
	intern_id_t[user_id_t] m_ids_file_map;
}

private void writeBlankDbFile(File handle)
{
	handle.seek(0);

	enforce(handle.tell() == OnDiskPersistance.OffsetMagic);
	handle.writeUlong(OnDiskPersistance.Magic);

	enforce(handle.tell() == OnDiskPersistance.OffsetNumImages);
	handle.writeUint(0);

	enforce(handle.tell() == OnDiskPersistance.OffsetBucketSizes);
	foreach(i; 0..NumBuckets)
	{
		handle.writeUint(0);
	}

	enforce(handle.tell() == OnDiskPersistance.OffsetImageData);

	handle.flush();
	handle.seek(0);
}

version(unittest) {
	static string test_file_path = "test/test_readwrite.tmp";
	import std.file : remove;
	import std.stdio : writeln;
	import std.algorithm : equal;

	auto getBlankDatabase(string file_path) {
		assert(!exists(file_path));
		return OnDiskPersistance.fromFile(test_file_path, true);
	}

	ImageIdSigDcRes imageFromFile(user_id_t id, string path) {
		ImageSigDcRes i = ImageSigDcRes.fromFile(path);
		ImageIdSigDcRes img = ImageIdSigDcRes(id, i.sig, i.dc, i.res);
		return img;
	}

	static ~this() {
		if(exists(test_file_path)) {
			remove(test_file_path);
		}
	}
}

unittest {
	scope(exit) { remove(test_file_path); }
	scope OnDiskPersistance db = getBlankDatabase(test_file_path);
	assert(db.length == 0);
}

unittest {
	scope(exit) { remove(test_file_path); }
	scope OnDiskPersistance db = getBlankDatabase(test_file_path);
	assert(!db.dirty);
}

unittest {
	scope(exit) { remove(test_file_path); }
	scope OnDiskPersistance db = getBlankDatabase(test_file_path);

	foreach(ImageIdSigDcRes img; db.imageDataIterator()) {
		assert(false);
	}
}

unittest {
	scope(exit) { remove(test_file_path); }
	scope OnDiskPersistance db = getBlankDatabase(test_file_path);
	auto img1 = imageFromFile(0, "test/cat_a1.jpg");

	assert(db.length == 0);
	db.appendImage(img1);
	bool thrown = false;
	try {
		db.length;
	} catch(OnDiskPersistance.DatabaseDirtyException e) {
		thrown = true;
	}
	assert(thrown);
}

unittest {
	scope(exit) { remove(test_file_path); }
	scope OnDiskPersistance db = getBlankDatabase(test_file_path);
	auto img1 = imageFromFile(0, "test/cat_a1.jpg");

	assert(db.length == 0);
	db.appendImage(img1);
	db.save();
	assert(db.length == 1);
}

unittest {
	scope(exit) { remove(test_file_path); }
	scope OnDiskPersistance db = getBlankDatabase(test_file_path);
	db.appendImage(imageFromFile(0, "test/cat_a1.jpg"));

	// Dirty database shouldn't allow itteration over its data
	bool thrown = false;
	try {
		db.imageDataIterator();
	} catch(OnDiskPersistance.DatabaseDirtyException e) {
		thrown = true;
	}
	assert(thrown);

	db.save();
	auto itr = db.imageDataIterator();

	// Iterator should fail when the outer db is made
	// dirty after iterator construction
	db.appendImage(imageFromFile(1, "test/cat_a2.jpg"));

	thrown = false;
	try {
		writeln("Iterator is empty: ", itr.empty);
		writeln("Database is dirty: ", db.dirty);
		foreach(img; itr) {
			assert(false);
		}
	} catch(OnDiskPersistance.DatabaseDirtyException e) {
		thrown = true;
	}
	assert(thrown);
}

unittest {
	scope(exit) { remove(test_file_path); }
	scope OnDiskPersistance db = getBlankDatabase(test_file_path);
	auto img1 = imageFromFile(0, "test/cat_a1.jpg");
	db.appendImage(img1);

	bool thrown = false;
	try {
		db.getImage(0);
	} catch(OnDiskPersistance.DatabaseDirtyException e) {
		thrown = true;
	}
	assert(thrown);

	db.save();
	assert(db.getImage(0) == img1);
}

unittest {
	scope(exit) { remove(test_file_path); }
	scope OnDiskPersistance db = getBlankDatabase(test_file_path);
	auto img1 = imageFromFile(0, "test/cat_a1.jpg");
	db.appendImage(img1);

	db.save();
	bool thrown = false;
	try {
		db.getImage(1564);
	} catch(BaseDb.IdNotFoundException e) {
		thrown = true;
	}
	assert(thrown);
}

unittest {
	scope(exit) { remove(test_file_path); }
	scope OnDiskPersistance db = getBlankDatabase(test_file_path);

	auto img1 = imageFromFile(1, "test/cat_a1.jpg");
	auto img2 = imageFromFile(2, "test/cat_a2.jpg");
	auto img3 = imageFromFile(3, "test/small_png.png");
	db.appendImage(img1);
	db.appendImage(img2);
	db.appendImage(img3);
	db.save();

	auto ret = db.removeImage(2);
	db.save();

	assert(ret == img2);
	assert(db.length == 2);
	foreach(i; db.imageDataIterator()) {
		assert(i != img2);
	}
}

unittest {
	scope(exit) { remove(test_file_path); }
	{
		scope OnDiskPersistance db = OnDiskPersistance.fromFile(test_file_path, true);
		assert(db.hasValidHeaders());
	}
	// Test that new datbases are written and valid.
	{
		scope OnDiskPersistance db = OnDiskPersistance.fromFile(test_file_path);
		assert(db.hasValidHeaders());
	}
}

unittest {
	scope(exit) { remove(test_file_path); }
	auto img1 = imageFromFile(1, "test/cat_a1.jpg");
	auto img2 = imageFromFile(2, "test/cat_a2.jpg");
	auto img3 = imageFromFile(3, "test/small_png.png");

	// Test that closing the DB flushes the write queue
	{
		scope db = getBlankDatabase(test_file_path);
		db.appendImage(img1);
		db.appendImage(img2);
		db.appendImage(img3);
	}

	// And reopening the database yields the same image data
	{
		scope db = OnDiskPersistance.fromFile(test_file_path);
		assert(db.length == 3);
		assert(equal(db.imageDataIterator(), [img1, img2, img3]));
	}
}

unittest {
	scope(exit) { remove(test_file_path); }
	auto img1 = imageFromFile(1, "test/cat_a1.jpg");
	auto img2 = imageFromFile(2, "test/cat_a2.jpg");
	auto img3 = imageFromFile(3, "test/small_png.png");

	// Test that closing the DB flushes the write queue
	{
		scope db = getBlankDatabase(test_file_path);
		db.appendImage(img1);
		db.appendImage(img2);
		db.appendImage(img3);
	}

	{
		scope db = OnDiskPersistance.fromFile(test_file_path);
		auto ret = db.removeImage(3);
		assert(ret == img3);
	}

	// And reopening the database yields the same image data
	{
		scope db = OnDiskPersistance.fromFile(test_file_path);
		assert(db.length == 2);
		assert(equal(db.imageDataIterator(), [img1, img2]));
	}
}

unittest {
	scope(exit) { remove(test_file_path); }
	scope db = getBlankDatabase(test_file_path);
	db.appendImage(imageFromFile(1, "test/cat_a1.jpg"));
	db.appendImage(imageFromFile(2, "test/cat_a2.jpg"));
	db.appendImage(imageFromFile(3, "test/small_png.png"));

	bool thrown = false;
	try {
		db.bucketSizes();
	} catch(OnDiskPersistance.DatabaseDirtyException e) {
		thrown = true;
	}
	assert(thrown);

	db.save();
	bool oneWasntZero;
	foreach(size; db.bucketSizes().sizes) {
		if(size != 0)
			oneWasntZero = true;
	}
	assert(oneWasntZero);
}

unittest {
	scope(exit) { remove(test_file_path); }
	scope db = getBlankDatabase(test_file_path);
	db.appendImage(imageFromFile(1, "test/cat_a1.jpg"));
	db.appendImage(imageFromFile(2, "test/cat_a2.jpg"));
	db.appendImage(imageFromFile(3, "test/small_png.png"));
	db.save();

	db.removeImage(1);
	db.removeImage(2);
	db.removeImage(3);
	db.save();

	bool oneWasntZero;
	foreach(size; db.bucketSizes().sizes) {
		if(size != 0)
			oneWasntZero = true;
	}
	assert(oneWasntZero == false);
}

unittest {
	scope(exit) { remove(test_file_path); }
	scope db = getBlankDatabase(test_file_path);
	db.appendImage(imageFromFile(1, "test/cat_a1.jpg"));
	db.save();

	int numOne;
	foreach(size; db.bucketSizes().sizes) {
		if(size == 1)
			numOne++;
	}
	assert(numOne == NumSigCoeffs*NumColorChans);
}
