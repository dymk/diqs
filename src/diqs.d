module diqs;

import reserved_array;
import haar;
import magick_wand.all;
import consts;
import types;
import image_db.all;

import std.stdio;
import std.file;
import std.stdio;
import std.string;
import std.algorithm;
import std.array;
import std.datetime;
//import std.parallelism : taskPool;
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

	write("Database name:\n> ");
	string dbname = readln().chomp();
	string dbpath = "test/ignore/"~dbname;

	if(exists(dbpath)) {
		writeln("Loading prexisting database");
	}

	auto db = FileDb.fromFile(dbpath, true);
	writeln("Database has ", db.numImages(), " loaded after opening");

	if(db.numImages() == 0)
	{
		write("Directory to load:\n> ");
		string dir = readln().chomp();
		loadDirectory(db, dir);
		db.save();
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
			writefln("ID: %3d : %s%%", res.image.user_id, res.similarity);
		}

		write("Enter image path to compare:\n> ");
	}

	return;
}

void loadDirectory(FileDb db, string dir)
{
	auto gen = new IdGen!user_id_t;
	int index = 0;
	foreach(name; dirEntries(dir, SpanMode.breadth)) {
		auto id = gen.next();
		auto img = ImageSigDcRes.fromFile(name);
		auto imgWithId = ImageIdSigDcRes(id, img.sig, img.dc, img.res);

		db.addImage(imgWithId);

		stderr.writeln(id, ":", name);
		if(index % 500 == 0 && index != 0) {
			writeln("Syncing database with disk");
			db.save();
		}
		index++;
	}

	writeln("Loaded ", db.numImages(), " images.");
	return;
}
