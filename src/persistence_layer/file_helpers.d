module persistence_layer.file_helpers;

import vibe.core.file :
  existsFile,
  openFile,
  FileMode,
  FileStream;

// Helper functions for reading and writing
// values of various sizes to a file
FileStream writeUlong(FileStream file, ulong val) {
	return writeValue!ulong(file, val);
}

FileStream writeUint(FileStream file, uint val) {
	return writeValue!uint(file, val);
}

uint readUint(FileStream file) {
	return readValue!uint(file);
}

ulong readUlong(FileStream file) {
	return readValue!ulong(file);
}

FileStream writeValue(T)(FileStream file, T val) {
	ubyte[T.sizeof] val_bytes = *(cast(ubyte[T.sizeof]*)(&val));
	file.write(val_bytes);
	return file;
}

T readValue(T)(FileStream file) {
	T val;
	ubyte[T.sizeof] val_bytes;
	file.read(val_bytes);
	val = *(cast(T*)val_bytes.ptr);
	return val;
}

version(unittest) {
	import sig : ImageIdSigDcRes, ImageSigDcRes;
	import types : user_id_t;

	import std.file : remove;
	import std.stdio : writeln;

	static string test_file_path = "test/test_readwrite.tmp";

	ImageIdSigDcRes imageFromFile(user_id_t id, string path) {
		ImageSigDcRes i = ImageSigDcRes.fromFile(path);
		ImageIdSigDcRes img = ImageIdSigDcRes(id, i.sig, i.dc, i.res);
		return img;
	}
}

unittest {
	FileStream a = openFile(test_file_path, FileMode.readWrite);
	scope(exit) { remove(test_file_path); }
	scope(exit) { a.close(); }

	a.writeUint(10);
	a.close();

	a = openFile(test_file_path, FileMode.readWrite);

	uint test = a.readUint();
	assert(test == 10);
}

unittest {
	FileStream a = openFile(test_file_path, FileMode.readWrite);
	scope(exit) { remove(test_file_path); }
	scope(exit) { a.close(); }

	a.writeUlong(4598741);
	a.close();

	a = openFile(test_file_path, FileMode.readWrite);

	ulong test = a.readUlong();
	assert(test == 4598741);
}

unittest {
	FileStream a = openFile(test_file_path, FileMode.readWrite);
	scope(exit) { remove(test_file_path); }
	scope(exit) { a.close(); }

	a.writeUlong(4598741);
	a.close();

	a = openFile(test_file_path, FileMode.readWrite);

	ulong test = a.readUlong();
	assert(test == 4598741);
}

unittest {
	FileStream a = openFile(test_file_path, FileMode.readWrite);
	scope(exit) { remove(test_file_path); }
	scope(exit) { a.close(); }

	float foo = 42093422.6190246420913190234324420913190246;
	a.writeValue!float(foo);
	a.close();

	a = openFile(test_file_path, FileMode.readWrite);

	float test = a.readValue!float();
	assert(test == foo);
}

unittest {
	struct Foo {
		float f;
	}
	Foo foo = { 42091.6190246420913190246420913190246 };

	FileStream a = openFile(test_file_path, FileMode.readWrite);
	scope(exit) { remove(test_file_path); }

	a.writeValue(foo);
	a.close();

	a = openFile(test_file_path, FileMode.readWrite);
	scope(exit) { a.close(); }
	assert(a.readValue!Foo() == foo);
}

unittest {

	struct Foo {
		size_t st;
		uint ui;
		int i;
		byte b;
		long l;
		float f;
		double d;
	}

	Foo f;
	f.st = 98123;
	f.ui = 8723;
	f.i = -8234582;
	f.b = 120;
	f.l = 1_000_020;
	f.f = 765342.642091024264;
	f.d = -8674209024783624703276453.240937024387624075224746320739072436;

	FileStream a = openFile(test_file_path, FileMode.readWrite);
	scope(exit) { remove(test_file_path); }

	a.writeValue(f);
	a.close();

	a = openFile(test_file_path, FileMode.readWrite);
	scope(exit) { a.close(); }

	Foo test = a.readValue!Foo();
	assert(test.st == 98123);
	assert(test.ui == 8723);
	assert(test.i == -8234582);
	assert(test.b == 120);
	assert(test.l == 1_000_020);
	assert(test.f == cast(float)765342.642091024264);
	assert(test.d == -8674209024783624703276453.240937024387624075224746320739072436);
}

unittest {
	 ImageIdSigDcRes image = imageFromFile(1, "test/cat_a2.jpg");
	 FileStream a = openFile(test_file_path, FileMode.readWrite);
	 scope(exit) { remove(test_file_path); }
	 scope(exit) { a.close(); }

	 a.writeValue!ImageIdSigDcRes(image);
	 a.close();

	 a = openFile(test_file_path, FileMode.readWrite);

	 auto test = a.readValue!ImageIdSigDcRes();
	 assert(test == image);
}
