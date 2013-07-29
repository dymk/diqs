module diqs;

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

	//writeln("Start typing in file names: ");
	//foreach(line; stdin.byLine()) {
	//	string s = (cast(string)line).chomp();
	//	if(s == "") { break; }
	//	auto imgdata = ImageData.fromFile(s);
	//	db.addImage(imgdata);
	//	writeln("Processed ", s);
	//}

	writeln("Loading images...");
	auto imgdata = ImageData.fromFile("test/cat_a1.jpg");
	GC.disable;
	foreach(i; 0..50_000) {
		db.addImage(imgdata);
		if(i > 0 && (i % 1000) == 0)
			writeln(i, " images loaded...");
	}
	GC.enable;

	writeln("Database has ", db.numImages(), " images.");
	//writeln("Enter filenames to query against: ");

	//foreach(line; stdin.byLine()) {
	//	auto str = (cast(string)line).chomp();
	//	if(isFile(str))
	//	{
	//		auto imgdata = ImageData.fromFile(str);
	//		results = db.query(imgdata, 5);
	//	}
	//	else
	//	{
	//		writeln("'", str, "' is not a valid file");
	//	}
	//}

	//auto a = stdin.byLine().front;
}
