module diqs;

import reserved_array;
import haar;
import magick_wand.all;
import consts;
import types;
import image_db.all;

import std.stdio;
import std.file;
import std.file : remove;
import std.stdio;
import std.string;
import std.algorithm;
import std.array;
import std.datetime;
import std.parallelism : taskPool;
import core.memory;
import core.time;
import core.exception : OutOfMemoryError;

void main()
{

	version(unittest) {
		writeln("Size of BucketManager: ", __traits(classInstanceSize, BucketManager));
		writeln("Size of Bucket: ", Bucket.sizeof);
		writeln("Size of ImageIdSigDcRes: ", ImageIdSigDcRes.sizeof);
		writeln("Size of ImageSig: ", ImageSig.sizeof);
		writeln("Size of ImageRes: ", ImageRes.sizeof);
		writeln("Size of ImageDc: ", ImageDc.sizeof);
		writeln("Size of size_t: ", size_t.sizeof);
		writeln("All unittests passed");
		return;
	}


	version(SpeedTest) {
		// Loads a directory of images, writes it to the disk, then exits.

		string testdb = "test/ignore/speedtest.diqs";
		if(exists(testdb)) { remove(testdb); }
		auto speedtest_db = FileDb.fromFile(testdb, true);
		loadDirectory(speedtest_db, "test/ignore/search_1_2_resized");
		speedtest_db.save();
		return;
	}

	write("Database name (created in test/ignore):\n> ");
	string dbname = readln().chomp();
	//string dbname = "smalldb";
	string dbpath = "test/ignore/"~dbname;

	if(exists(dbpath) && isFile(dbpath)) {
		writeln("Loading prexisting database");
	}

	auto db = FileDb.fromFile(dbpath, true);
	writeln("Database has ", db.numImages(), " loaded after opening");

	write("Directory to load:\n> ");

	string loaddir;
	while((loaddir = readln()) !is null)
	{
		loaddir = loaddir.chomp();
		if(loaddir == "")
			break;

		loadDirectory(db, loaddir);

		writeln("Syncing database with disk");
		db.save();

		write("\n> ");
	}

	string querypath;
	write("Enter image path to compare:\n> ");
	while((querypath = readln()) !is null)
	{
		querypath = querypath.chomp();
		if(querypath == "")
			break;

		auto query_image = ImageSigDcRes.fromFile(querypath);
		QueryParams query_params;
		query_params.in_image = &query_image;
		query_params.num_results = 15;
		query_params.ignore_color = false;

		scope results = db.query(query_params);
		foreach(index, res; results)
		{
			writefln("ID: %3d : %3f%%", res.image.user_id, res.similarity);
		}

		write("\n> ");
	}

	db.close();
	return;
}

void loadDirectory(FileDb db, string dir)
{

	int index = 0;
	foreach(name; dirEntries(dir, SpanMode.breadth)) {
		auto img = ImageSigDcRes.fromFile(name);
		auto id = db.addImage(img);

		stderr.writeln(id, ":", name);
		if(index % 500 == 0 && index != 0) {
			//writeln("Syncing database with disk");
			//db.save();
		}
		index++;
	}

	writeln("Loaded ", db.numImages(), " images.");
	return;
}
