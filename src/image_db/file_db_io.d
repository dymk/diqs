module image_db.file_db_io;

/**
 * Abstracts away the actual file format of
 * a FileDb.
 *
 *
 * Database structure:
 * where N is the number of images in the database
 * where NumBuckets = (NumColorChans * (ImageArea*2 - 1))
 *       NumBuckets = 98,301
 *
 * - ImageIdSigDcRes: 264 bytes
 *   Breakdown ----------------
 *   - user_id_t id :   8 bytes
 *   - ImageSig sig : 240 bytes
 *   - ImageDc dc   :  12 bytes
 *   - ImageRes res :   4 bytes
 *
 * - type                | bytes          | Offset    |    name       |    description
 * - ulong               | 8              | 0         | magic         | A sanity check to make sure it's a DIQS database
 * - uint                | 4              | 8         | num_images    | Number of images (N) in the database
 * - uint[NumBuckets]    | 4 * NumBuckets | 12        | bucket_sizes  | Number of images in a given bucket (size hint)
 * - ImageIdSigDcRes[N]  | 264 * N        | 393,216   | image_data    | Signature and user ID data for the images in the db
 *
 */

import std.stdio : File, SEEK_END;
//import std.typecons : Tuple;
//import std.container : Array;
import std.exception : enforce;
import std.file : exists;
import std.string : format;
import std.conv : to;

import core.memory : GC;

import image_db.bucket_manager :
  BucketManager,
  BucketSizes;

import sig :
  ImageIdSigDcRes,
  ImageSigDcRes,
  ImageRes,
  ImageDc;

import consts :
  NumBucketsPerChan,
  NumColorChans,
  NumSigCoeffs,
  NumBuckets;

import types :
  sig_t,
  coeffi_t,
  user_id_t;


class FileFormatException : Exception {
	public this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
};
class MagicException : FileFormatException {
	public this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
};
class IndexOutOfRangeException : FileFormatException {
	public this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
};
//class SizeException : FileFormatException {
//	public this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
//};

struct FileDbIo
{
	enum ulong Magic       = 0xDEADBEEF;
	enum OffsetMagic       = 0;
	enum OffsetNumImages   = ulong.sizeof;
	enum OffsetBucketSizes = OffsetNumImages + uint.sizeof;
	enum OffsetImageData   = OffsetBucketSizes + (uint.sizeof * NumBuckets);

	this(string path, bool create_if_nonexistant = true)
	{
		this.load(path, create_if_nonexistant);
	}

	static FileDbIo load(string path, bool create_if_nonexistant = true)
	{
		File handle;

		if(!exists(path) && !create_if_nonexistant) {

			if(create_if_nonexistant)
			{
				handle = File(path, "wb+");
				FileDbIo.writeBlankDbFile(handle);
			}
			else
			{
				throw new Exception("Database '" ~ path ~ "' does not exist");
			}
		}
		else
		{
			handle = File(path, "wb+");
		}

		return FileDbIo.load(handle);
	}

	static FileDbIo load(File handle)
	{
		//// Check the DB is of a sane size
		//handle.seek(SEEK_END);
		//if(handle.tell() < OffsetImageData)
		//{
		//	throw new SizeException("Database seems too short: Should be at least " ~ to!string(OffsetImageData) ~ " but was only " ~ to!string(handle.tell()));
		//}

		handle.seek(0);
		ulong magic = handle.readUlong();
		if(magic != Magic) {
			throw new MagicException("Magic was " ~ to!string(magic) ~ " instead of expected " ~ to!string(Magic));
		}

		enforce(handle.tell() == OffsetNumImages);
		uint num_images = handle.readUint();

		enforce(handle.tell() == OffsetBucketSizes);
		BucketSizes* bucket_sizes = new BucketSizes;
		foreach(ref int bucket_size; bucket_sizes.sizes)
		{
			uint size = handle.readUint();
			enforce(size <= int.max);
			bucket_size = cast(int) size;
		}

		enforce(handle.tell() == OffsetImageData);

		FileDbIo ret;
		ret.num_images = num_images;
		ret.bucket_sizes = bucket_sizes;
		ret.handle = handle;
		return ret;
	}

	ImageIdSigDcRes readImage(size_t at)
	{
		if(at < length) {
			throw new IndexOutOfRangeException("Index at " ~ to!string(at) ~ " is out of range (length " ~ to!string(length) ~ ")");
		}

		handle.seek(OffsetImageData + (at * ImageIdSigDcRes.sizeof));
		return handle.readValue!ImageIdSigDcRes();
	}

	size_t writeImage(size_t at, ref ImageIdSigDcRes img, bool sync_headers = true) {
		// Write at the given location
		handle.seek(OffsetImageData + (at * ImageIdSigDcRes.sizeof));
		handle.writeValue!ImageIdSigDcRes(img);

		num_images++;

		foreach(ubyte chan, ref sig_t sig; img.sig.sigs) {

			int[] chan_sizes = bucket_sizes.forChan(chan);
			foreach(coeffi_t coeff; sig)
			{
				ushort index = BucketManager.bucketIndexForCoeff(coeff);
				chan_sizes[index]++;
			}
		}

		if(sync_headers) {
			writeHeaders();
		}

		return length;
	}

	void writeHeaders() {
		handle.seek(OffsetNumImages);
		handle.writeUint(num_images);

		handle.seek(OffsetBucketSizes);
		foreach(uint bucket_size; this.bucket_sizes.sizes) {
			handle.writeUint(bucket_size);
		}
	}

	size_t appendImage(ref ImageIdSigDcRes img, bool sync_headers = true) {
		return writeImage(this.length, img, sync_headers);
	}

	ImageDataRange imageDataRange() {
		return ImageDataRange(&this);
	}

	struct ImageDataRange
	{
		this(FileDbIo* outer)
		{
			this.outer = outer;
			this.outer.handle.seek(OffsetImageData);
		}

		ImageIdSigDcRes front() {
			ImageIdSigDcRes ret = readValue!ImageIdSigDcRes(outer.handle);
			return ret;
		}

		void popFront() {
			// This is technically redundant
			outer.handle.seek((curpos + 1) * ImageIdSigDcRes.sizeof);
			curpos++;
		}

		bool empty()
		in {
			if(outer.handle.eof() && (curpos != outer.length))
			{
				assert(false, "At EOF but only at " ~ to!string(curpos) ~ " out of " ~ to!string(outer.length) ~ " total");
			}
		}
		body {
			return curpos == outer.num_images;
		}

	private:
		size_t curpos = 0;
		FileDbIo* outer;
	}

	static void writeBlankDbFile(File db)
	{
		db.seek(0);

		enforce(db.tell() == OffsetMagic);
		db.writeUlong(Magic);

		enforce(db.tell() == OffsetNumImages);
		db.writeUint(0);

		enforce(db.tell() == OffsetBucketSizes);
		foreach(i; 0..NumBuckets)
		{
			db.writeUint(0);
		}

		enforce(db.tell() == OffsetImageData);

		db.flush();
		db.seek(0);
	}

	static bool isValidDb(string path)
	{
		File f = File(path, "rb");
		return isValidDb(f);
	}

	// Checks that the DB has the magic marker and is
	// a sane length
	static bool isValidDb(File file)
	{
		file.seek(0);
		ulong magic = readUlong(file);
		return magic == Magic;
	}

	size_t length() @property {
		return cast(size_t) num_images;
	}

	bool empty() @property {
		return length == 0;
	}

	~this() {
		handle.close();
		GC.free(bucket_sizes);
	}

	uint num_images;
	BucketSizes* bucket_sizes;
	File handle;
}

// Helper functions for reading and writing
// values of various sizes to a file
File writeUlong(File file, ulong val) {
	return writeValue!ulong(file, val);
}

File writeUint(File file, uint val) {
	return writeValue!uint(file, val);
}

uint readUint(File file) {
	return readValue!uint(file);
}

ulong readUlong(File file) {
	return readValue!ulong(file);
}

File writeValue(T)(File file, T val) {
	ubyte[T.sizeof] val_bytes = *(cast(ubyte[T.sizeof]*)(&val));
	file.rawWrite(val_bytes);
	return file;
}

T readValue(T)(File file) {
	T val;
	ubyte[T.sizeof] val_bytes;
	file.rawRead(val_bytes);
	val = *(cast(T*)val_bytes.ptr);
	return val;
}

version(unittest) {
	static string test_file_path = "test/test_readwrite.tmp";
	import std.file : remove;
	import std.stdio : writeln;

	FileDbIo getBlankDatabase(string file_path) {
		File a = File(test_file_path, "wb+");
		FileDbIo.writeBlankDbFile(a);
		return FileDbIo.load(a);
	}

	ImageIdSigDcRes imageFromFile(user_id_t id, string path) {
		ImageSigDcRes i = ImageSigDcRes.fromFile(path);
		ImageIdSigDcRes img = ImageIdSigDcRes(1, i.sig, i.dc, i.res);
		return img;
	}
}

unittest {
	scope(exit) { remove(test_file_path); }
	FileDbIo db = getBlankDatabase(test_file_path);

	foreach(bucket_size; db.bucket_sizes.sizes) {
		assert(bucket_size == 0);
	}

	auto img1 = imageFromFile(1, "test/cat_a1.jpg");
	auto img2 = imageFromFile(2, "test/cat_a2.jpg");

	assert(db.length == 0);
	db.appendImage(img1);
	assert(db.length == 1);

	// Check that the correct number of buckets have been incremented
	int non_zero_buckets = 0;
	foreach(bucket_size; db.bucket_sizes.sizes) {
		if(bucket_size == 1)
			non_zero_buckets++;
	}
	assert(non_zero_buckets == NumSigCoeffs * NumColorChans);

	db.appendImage(img2);
	assert(db.length == 2);

}

unittest {
	scope(exit) { remove(test_file_path); }
	FileDbIo db = getBlankDatabase(test_file_path);
	auto img = imageFromFile(1, "test/small_png.png");
	db.appendImage(img);
	assert(db.empty == false);
	assert(db.num_images == 1);
	foreach(ref i; db.imageDataRange()) {
		assert(i == img);
	}
}

unittest {
	scope(exit) { remove(test_file_path); }
	FileDbIo db = getBlankDatabase(test_file_path);

	auto itr = db.imageDataRange();
	assert(itr.empty);

	// Ensure there are no images to iterate over
	foreach(ref ImageIdSigDcRes img; itr) {
		assert(false);
	}
}

unittest {
	scope(exit) { remove(test_file_path); }
	FileDbIo db = getBlankDatabase(test_file_path);

	assert(db.empty);
	assert(db.num_images == 0);
	foreach(bucket_size; db.bucket_sizes.sizes) {
		assert(bucket_size == 0);
	}
}

unittest {
	scope(exit) { remove(test_file_path); }
	File a = File(test_file_path, "wb+");

	FileDbIo.writeBlankDbFile(a);
	assert(FileDbIo.isValidDb(a));
}

unittest {
	File a = File(test_file_path, "wb");
	scope(exit) { remove(test_file_path); }
	scope(exit) { a.close(); }

	a.writeUint(10);
	a.close();

	a = File(test_file_path, "rb");

	uint test = a.readUint();
	assert(test == 10);
}

unittest {
	File a = File(test_file_path, "wb");
	scope(exit) { remove(test_file_path); }
	scope(exit) { a.close(); }

	a.writeUlong(4598741);
	a.close();

	a = File(test_file_path, "rb");

	ulong test = a.readUlong();
	assert(test == 4598741);
}

unittest {

	struct Foo {
		size_t st;
		uint ui;
		int i;
		byte b;
		long l;
	}

	Foo f;
	f.st = 98123;
	f.ui = 8723;
	f.i = -8234582;
	f.b = 120;
	f.l = 1_000_020;

	File a = File(test_file_path, "wb");
	scope(exit) { remove(test_file_path); }

	a.writeValue(f);
	a.close();

	a = File(test_file_path, "rb");
	scope(exit) { a.close(); }

	Foo test = a.readValue!Foo();
	assert(test.st == 98123);
	assert(test.ui == 8723);
	assert(test.i == -8234582);
	assert(test.b == 120);
	assert(test.l == 1_000_020);
}
