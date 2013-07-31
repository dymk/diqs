module diqs;

//import reserved_array;
import haar;
import magick_wand;
import consts;
import types;
import image_db;
import sig : IDImageData;

void main()
{
	//writeln("Size of IDImageData: ", IDImageData.sizeof);
	//writeln("Size of BucketManager: ", __traits(classInstanceSize, BucketManager));
	//writeln("Size of Bucket: ", Bucket.sizeof);

	auto db = new MemDB();

	import std.file;
	import std.stdio;
	import std.string;
	import std.algorithm;
	import std.array;
	import core.memory;

	writeln("Loading images...");
	auto imgdata = ImageData.fromFile("test/cat_a1.jpg");
	GC.disable();
	foreach(i; 0..100_000) {
		db.addImage(imgdata);
		if(i > 0 && (i % 10_000) == 0)
		{
			writeln(i, " images loaded...");

			//if(i % 10_000)
			//{
			//	GC.enable();
			//	GC.collect();
			//	GC.disable();
			//}
		}
	}
	GC.enable();

	writeln("Database has ", db.numImages(), " images.");

	//auto a = stdin.byLine().front;
}
