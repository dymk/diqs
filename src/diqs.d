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

	//version(unittest) {
	//	writeln("All unittests passed");
	//	return;
	//}

	import std.file;
	import std.stdio;
	import std.string;
	import std.algorithm;
	import std.array;
	import core.memory;
	import core.exception : OutOfMemoryError;

	writeln("Loading images...");
	auto img1 = ImageSigDcRes.fromFile("test/cat_a1.jpg");
	auto img2 = ImageSigDcRes.fromFile("test/cat_a2.jpg");

	db.addImage(img1);
	db.addImage(img2);
	db.addImage(ImageSigDcRes.fromFile("test/ignore/random_search_1/images(7).jpg"));

	//GC.disable();
	//try
	//{
	//	foreach(i; 0..10_000_000) {
	//		db.addImage(imgdata);
	//		if(i > 0 && (i % 10_000) == 0)
	//		{
	//			writeln(i, " images loaded...");

	//			GC.enable();
	//			GC.collect();
	//			GC.disable();
	//		}
	//	}
	//}
	//catch(OutOfMemoryError e)
	//{
	//	GC.enable();
	//	writeln("Ran out of memory! number of images loaded: ", db.numImages());
	//}

	auto queryimage = img2;

	QueryParams query_params;
	query_params.in_image = &queryimage;
	query_params.num_results = 15;
	query_params.ignore_color = false;

	scope results = db.query(query_params);
	writeln("Results: ", results);

	//auto a = stdin.byLine().front;
}
