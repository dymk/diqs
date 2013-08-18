module diqs;

import reserved_array;
import haar;
import magick_wand.all;
import consts;
import types;
import image_db.all;

import std.stdio;

void main()
{
	writeln("Size of BucketManager: ", __traits(classInstanceSize, BucketManager));
	writeln("Size of Bucket: ", Bucket.sizeof);
	writeln("Size of size_t: ", size_t.sizeof);

	auto db = new MemDb();

	version(unittest) {
		writeln("All unittests passed");
		return;
	}

	import std.file;
	import std.stdio;
	import std.string;
	import std.algorithm;
	import std.array;
	import core.memory;
	import core.exception : OutOfMemoryError;

	writeln("Loading images...");
	auto imgdata = ImageSigDcRes.fromFile("test/cat_a1.jpg");
	GC.disable();
	try
	{
		foreach(i; 0..10_000_000) {
			db.addImage(imgdata);
			if(i > 0 && (i % 10_000) == 0)
			{
				writeln(i, " images loaded...");

				GC.enable();
				GC.collect();
				GC.disable();
			}
		}
	}
	catch(OutOfMemoryError e)
	{
		GC.enable();
		writeln("Ran out of memory! number of images loaded: ", db.numImages());
	}

	auto queryimage = ImageSigDcRes.fromFile("test/cat_a2.jpg");

	//QueryParams query;
	//query.in_image = &queryimage;
	//query.num_results = 15;
	//query.ignore_color = false;

	//scope QueryResult[] result = MemDb.query(query);


	writeln("Database has ", db.numImages(), " images.");
	auto a = stdin.byLine().front;
}
