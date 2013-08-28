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
	writeln("Size of ImageIdSigDcRes: ", ImageIdSigDcRes.sizeof);
	writeln("Size of ImageSig: ", ImageSig.sizeof);
	writeln("Size of ImageRes: ", ImageRes.sizeof);
	writeln("Size of ImageDc: ", ImageDc.sizeof);
	writeln("Size of size_t: ", size_t.sizeof);

	version(unittest) {
		writeln("All unittests passed");
		return;
	}

	auto db = new MemDb(10_000_000);

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

	writeln("Loading images...");
	auto img1 = ImageSigDcRes.fromFile("test/cat_a1.jpg");
	auto img2 = ImageSigDcRes.fromFile("test/cat_a2.jpg");

	db.addImage(img1);
	db.addImage(img2);
	//db.addImage(ImageSigDcRes.fromFile("test/ignore/random_search_1/images(7).jpg"));

	auto entries = dirEntries("test/ignore/search_1_2_resized/",SpanMode.breadth).array();

	//auto images = taskPool.amap!((string name) {
	auto images = map!((string name) {
		writeln("Mapping ", name);
		return ImageSigDcRes.fromFile(name);
	})(entries[0..500]).array();

	GC.free(entries.ptr);

	writeln("Inserting into db");
	{
		//auto mt = measureTime!((TickDuration a){
		//	writeln("Milliseconds to add images: ", a.msecs);
		//});
		foreach(x; 0..50)
		{
			writeln("Pushing ", x, " set of ", images.length);
			//foreach(i; taskPool.parallel(iota(images.length)))
			foreach(i; iota(images.length))
			{
				db.addImage(images[i]);
			}
		}
	}

	GC.free(images.ptr);

	writeln("Loaded ", db.numImages(), " images.");

	//foreach(string name; dirEntries("test/ignore/random_search_1_resized/",SpanMode.breadth))
	//{
	//	if(exists(name) && name[$-3..$] == "jpg")
	//	{
	//		i++;
	//		auto image_data = ImageSigDcRes.fromFile(name);
	//		db.addImage(image_data);
	//		if(i % 10 == 0)
	//		{
	//			writeln("Loaded ", i, " images");
	//		}
	//	}
	//}
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

	//auto queryimage = img2;

	//QueryParams query_params;
	//query_params.in_image = &queryimage;
	//query_params.num_results = 15;
	//query_params.ignore_color = false;

	//scope results = db.query(query_params);
	//foreach(index, res; results)
	//{
	//	writeln("Image ID: ", res.image.user_id, " similarity: ", res.similarity, "%");
	//}

	auto a = stdin.byLine().front;
}
