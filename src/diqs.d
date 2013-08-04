module diqs;

import reserved_array;
import haar;
import magick_wand.all;
import consts;
import types;
import image_db.all;
import sig : ImageIdSigDcRes;

import std.stdio;

void main()
{
	writeln("Size of IDImageData: ", ImageIdSigDcRes.sizeof);
	writeln("Size of BucketManager: ", __traits(classInstanceSize, BucketManager));
	writeln("Size of Bucket: ", Bucket.sizeof);
	writeln("Size of RA!user_id_t: ", ReservedArray!user_id_t.sizeof);
	writeln("Size of ImageDcRes: ", ImageDcRes.sizeof);

	auto db = new MemDb();

	//import std.file;
	//import std.stdio;
	//import std.string;
	//import std.algorithm;
	//import std.array;
	//import core.memory;

	version(unittest)
	{
		writeln("All tests pass");
		return;
	}

	writeln("Loading images...");
	auto imgdata = ImageSigDcRes.fromFile("test/cat_a1.jpg");
	GC.disable();
	foreach(i; 0..2_000_000) {
		db.addImage(imgdata, i);
		if(i > 0 && (i % 10_000) == 0)
		{
			writeln(i, " images loaded...");

			if(i % 10_000)
			{
				GC.enable();
				GC.collect();
				GC.disable();
			}
		}
	}
	GC.enable();

	//writeln("Database has ", db.numImages(), " images.");

	//auto a = stdin.byLine().front;
}
