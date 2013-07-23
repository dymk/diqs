module diqs;

import haar;
import magick_wand;
import consts;
import types;
import image_db;
import sig : IDImageData;

import std.stdio;

void main()
{
	writeln("Size of IDImageData: ", IDImageData.sizeof);
	writeln("Size of BucketManager: ", __traits(classInstanceSize, BucketManager));
	writeln("Size of Bucket: ", Bucket.sizeof);
}
