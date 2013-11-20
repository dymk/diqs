module image_db.file_db_unittests;

import image_db.file_db;

/// TODO: More test coverage for FileDb, covering stuff like
/// opened(), closed(), releaseMemDb(), etc

version(TestOnDiskPersistence)
{

	version(unittest)
	{
		import std.algorithm : equal;
		import std.stdio;
		import std.file : exists, remove;

		import sig : imageFromFile, sameAs;
		static string test_db_path = "test/test_file_db.db.tmp";
	}

	template CleanupDb() {
		const CleanupDb = q{
			scope(exit) {
				if(exists(test_db_path)) {
					remove(test_db_path);
				}
			}
		};
	}

	template TempScopeFileDb() {
		const TempScopeFileDb = q{
			FileDb db = FileDb.createFromFile(test_db_path);
			scope(exit) {
				db.destroy();
 				GC.free(cast(void*) db);
			}
		};
	}

	template SetupTempDb() {
		const SetupTempDb = q{
			mixin(CleanupDb!());
			mixin(TempScopeFileDb!());
		};
	}


	unittest {
		mixin SetupTempDb;
	}


	// Test that loadFromFile(path, true)
	// creates path if it doesn't exist
	unittest {
		mixin CleanupDb!();
		scope f = FileDb.loadFromFile(test_db_path, true);
		assert(exists(test_db_path));
	}

	// Test that loadFromFile(path, false)
	// throws if the file didn't exist
	unittest {
		mixin CleanupDb!();
		if(exists(test_db_path)) {
			remove(test_db_path);
		}

		bool throwed = false;
		try
		{
			auto f = FileDb.loadFromFile(test_db_path);
			//scope(exit) {
			//	f.destroy();
			//}
		}
		catch(FileDb.DbFileNotFoundException)
		{
			throwed = true;
		}
		assert(throwed);
	}

	//// Test that methods throw DbDirtyException
	//// if the database hasn't been flushed yet
	//unittest {
	//	mixin(SetupTempDb!());
	//	db.addImage(imageFromFile(0, "test/cat_a1.jpg"), false);

	//	assert(db.dirty());
	//	assert(!db.clean());

	//	bool throwed = false;
	//	try {
	//		db.numImages();
	//	}
	//	catch(FileDb.DbDirtyException)
	//	{
	//		throwed = true;
	//	}
	//	assert(throwed);

	//	//auto img2 = imageFromFile(1, "test/cat_a1.jpg");

	//	//db.addImage(img2, false);
	//	//db.flush();
	//	//assert(f.numImages() == 2);

	//	//auto ret = f.removeImage(0);
	//	//assert(ret.sameAs(img1));

	//	//assert(f.numImages() == 1);
	//}

	//unittest {
	//	scope(exit) { remove(test_db_path); }
	//	scope f = FileDb.loadFromFile(test_db_path, true);
	//	bool thrown = false;
	//	try {
	//		f.removeImage(0);
	//	} catch(BaseDb.IdNotFoundException e) {
	//		thrown = true;
	//	}
	//	assert(thrown);
	//}

	//unittest {
	//	scope(exit) { remove(test_db_path); }
	//	scope f = FileDb.loadFromFile(test_db_path, true);
	//	auto img1 = imageFromFile(0, "test/cat_a1.jpg");

	//	f.addImage(img1, false);

	//	bool thrown = false;
	//	try {
	//		f.imageDataIterator();
	//	} catch(FileDb.DbDirtyException e) {
	//		thrown = true;
	//	}
	//	assert(thrown);

	//	f.flush();
	//	assert(f.imageDataIterator().front().sameAs(img1));
	//}

	//// Test that calling the destructor flushes the database
	//unittest {
	//	scope(exit) { remove(test_db_path); }

	//	auto img1 = imageFromFile(0, "test/cat_a1.jpg");
	//	auto img2 = imageFromFile(1, "test/cat_a2.jpg");
	//	auto img3 = imageFromFile(3, "test/small_png.png");

	//	{
	//		scope f = FileDb.createFromFile(test_db_path);
	//		f.addImage(img1);
	//		f.addImage(img2);
	//		f.addImage(img3);
	//	}

	//	{
	//		scope f = FileDb.loadFromFile(test_db_path);
	//		assert(f.numImages() == 3);
	//		assert(equal!sameAs(f.imageDataIterator(), [img1, img2, img3]));
	//	}

	//}

	//unittest {
	//	scope(exit) { remove(test_db_path); }
	//	auto img1 = imageFromFile(0, "test/cat_a1.jpg");
	//	auto img2 = imageFromFile(1, "test/cat_a2.jpg");
	//	auto img3 = imageFromFile(3, "test/small_png.png");

	//	{
	//		scope f = FileDb.createFromFile(test_db_path);
	//		f.addImage(img1);
	//		f.addImage(img2);
	//		f.addImage(img3);
	//	}

	//	{
	//		scope f = FileDb.loadFromFile(test_db_path);
	//		f.removeImage(1, true);
	//	}

	//	{
	//		scope f = FileDb.loadFromFile(test_db_path);
	//		assert(equal!sameAs(f.imageDataIterator(), [img1, img3]));
	//	}

	//}
}
