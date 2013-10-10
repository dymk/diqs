module image_db.file_db_unittests;

import image_db.file_db;

/// TODO: More test coverage for FileDb, covering stuff like
/// opened(), closed(), releaseMemDb(), etc

version(unittest)
{
	import std.algorithm : equal;
	import std.stdio;
	import std.file : remove;

	import sig : imageFromFile, sameAs;
	static string test_db_path = "test/test_file_db.db.tmp";
}

unittest {
	scope(exit) { remove(test_db_path); }
	scope FileDb db = FileDb.createFromFile(test_db_path);
}


unittest {
	scope(exit) { remove(test_db_path); }
	scope f = FileDb.loadFromFile(test_db_path, true);
	auto img1 = imageFromFile(0, "test/cat_a1.jpg");
	auto img2 = imageFromFile(1, "test/cat_a1.jpg");

	f.addImage(img1);
	f.addImage(img2);
	f.flush();
	assert(f.numImages() == 2);

	auto ret = f.removeImage(0);
	assert(ret.sameAs(img1));

	assert(f.numImages() == 1);
}

unittest {
	scope(exit) { remove(test_db_path); }
	scope f = FileDb.loadFromFile(test_db_path, true);
	bool thrown = false;
	try {
		f.removeImage(0);
	} catch(BaseDb.IdNotFoundException e) {
		thrown = true;
	}
	assert(thrown);
}

unittest {
	scope(exit) { remove(test_db_path); }
	scope f = FileDb.loadFromFile(test_db_path, true);
	auto img1 = imageFromFile(0, "test/cat_a1.jpg");

	f.addImage(img1, false);

	bool thrown = false;
	try {
		f.imageDataIterator();
	} catch(FileDb.DbDirtyException e) {
		thrown = true;
	}
	assert(thrown);

	f.flush();
	assert(f.imageDataIterator().front().sameAs(img1));
}

unittest {
	scope(exit) { remove(test_db_path); }

	auto img1 = imageFromFile(0, "test/cat_a1.jpg");
	auto img2 = imageFromFile(1, "test/cat_a2.jpg");
	auto img3 = imageFromFile(3, "test/small_png.png");

	{
		scope f = FileDb.createFromFile(test_db_path);
		f.addImage(img1);
		f.addImage(img2);
		f.addImage(img3);
	}

	{
		scope f = FileDb.loadFromFile(test_db_path);
		writeln("Number images in this db: ", f.numImages());
		assert(f.numImages() == 3);
		assert(equal!sameAs(f.imageDataIterator(), [img1, img2, img3]));
	}

}

unittest {
	scope(exit) { remove(test_db_path); }
	auto img1 = imageFromFile(0, "test/cat_a1.jpg");
	auto img2 = imageFromFile(1, "test/cat_a2.jpg");
	auto img3 = imageFromFile(3, "test/small_png.png");

	{
		scope f = FileDb.createFromFile(test_db_path);
		f.addImage(img1);
		f.addImage(img2);
		f.addImage(img3);
	}

	{
		scope f = FileDb.loadFromFile(test_db_path);
		f.removeImage(1);
	}

	{
		scope f = FileDb.loadFromFile(test_db_path);
		assert(equal!sameAs(f.imageDataIterator(), [img1, img3]));
	}

}
