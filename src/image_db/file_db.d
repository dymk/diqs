module image_db.file_db;

/**
 * Represents an image database that can syncronize with the disk.
 */

import std.typecons : Tuple;
import std.exception : enforce;
import std.container : Array;
import std.file : exists;
import core.memory : GC;

import types :
  user_id_t,
  intern_id_t,
  coeffi_t,
  chan_t;

import sig :
  ImageIdSigDcRes,
  ImageSigDcRes,
  ImageRes,
  ImageDc;

import image_db.base_db : BaseDb;
import image_db.mem_db : MemDb;
import consts :
  ImageArea,
  NumColorChans,
  NumBuckets;

import persistance_layer.persistance_layer : PersistanceLayer;
import persistance_layer.on_disk_persistance : OnDiskPersistance;

class FileDb : BaseDb
{

	static FileDb fromFile(string path, bool create_if_nonexistant = false)
	{
		return new FileDb(OnDiskPersistance.fromFile(path, create_if_nonexistant));
	}

	this(PersistanceLayer persist_layer) {
		this.persist_layer = persist_layer;
		this.m_mem_db = new MemDb(this.persist_layer.length);

		m_mem_db.bucketSizeHint(persist_layer.bucketSizes());

		foreach(ref image; persist_layer.imageDataIterator()) {
			m_mem_db.addImage(image);
		}
	}

	user_id_t addImage(in ImageSigDcRes img) {
		auto ret = m_mem_db.addImage(img);
		ImageIdSigDcRes img_sig = ImageIdSigDcRes(ret, img.sig, img.dc, img.res);
		queueAddJob(img_sig);
		return ret;
	}

	user_id_t addImage(in ImageIdSigDcRes img) {
		auto ret = m_mem_db.addImage(img);
		queueAddJob(img);
		return ret;
	}

	size_t numImages() {
		version(unittest) {
			if(!persist_layer.dirty) {
				assert(m_mem_db.numImages() == persist_layer.length);
			}
		}
		return m_mem_db.numImages();
	}

	ImageIdSigDcRes removeImage(user_id_t id) {
		auto ret1 = persist_layer.removeImage(id);
		auto ret2 =      m_mem_db.removeImage(id);

		version(unittest) {
			assert(ret1.sameAs(ret2));
		}

		return ret1;
	}

	void save() {
		persist_layer.save();
	}

	~this() {
		persist_layer.destroy();
	}

	alias query = m_mem_db.query;
	alias imageDataIterator = persist_layer.imageDataIterator;

private:
	void queueAddJob(ImageIdSigDcRes img) {
		persist_layer.appendImage(img);
	}

	// Path to the database file this is bound to
	string m_db_path;
	scope PersistanceLayer persist_layer;
	MemDb m_mem_db;
}

version(unittest)
{
	import std.algorithm : equal;
	import std.stdio;
	import std.file : remove;

	static string tmp_db_path = "test/tmp_db_path.db";


	ImageIdSigDcRes imageFromFile(user_id_t id, string path) {
		ImageSigDcRes i = ImageSigDcRes.fromFile(path);
		ImageIdSigDcRes img = ImageIdSigDcRes(id, i.sig, i.dc, i.res);
		return img;
	}
}

unittest {
	scope(exit) { remove(tmp_db_path); }
	scope f = FileDb.fromFile(tmp_db_path, true);
	auto i = ImageSigDcRes.fromFile("test/cat_a1.jpg");
	assert(f.numImages() == 0);
	f.addImage(i);
	assert(f.numImages() == 1);
}

unittest {
	scope(exit) { remove(tmp_db_path); }
	scope f = FileDb.fromFile(tmp_db_path, true);
	auto img1 = imageFromFile(0, "test/cat_a1.jpg");
	auto img2 = imageFromFile(1, "test/cat_a1.jpg");

	f.addImage(img1);
	f.addImage(img2);
	f.save();

	auto ret = f.removeImage(0);
	assert(ret == img1);

	assert(f.numImages() == 0);
}

unittest {
	scope(exit) { remove(tmp_db_path); }
	scope f = FileDb.fromFile(tmp_db_path, true);
	bool thrown = false;
	try {
		f.removeImage(0);
	} catch(BaseDb.IdNotFoundException e) {
		thrown = true;
	}
	assert(thrown);
}

unittest {
	scope(exit) { remove(tmp_db_path); }
	scope f = FileDb.fromFile(tmp_db_path, true);
	auto img1 = imageFromFile(0, "test/cat_a1.jpg");
	auto img2 = imageFromFile(1, "test/cat_a2.jpg");

	f.appendImage(img1);
	f.appendImage(img2);

	bool thrown = false;
	try {
		f.imageDataIterator();
	} catch(OnDiskPersistance.DatabaseDirtyException e) {
		thrown = true;
	}
	assert(thrown);

	f.save();
	assert(equal(f.imageDataIterator(), [img1, img2]));
}

unittest {
	scope(exit) { remove(tmp_db_path); }
	auto img1 = imageFromFile(0, "test/cat_a1.jpg");
	auto img2 = imageFromFile(1, "test/cat_a2.jpg");
	auto img3 = imageFromFile(3, "test/small_png.png");

	{
		scope f = FileDb.fromFile(tmp_db_path, true);
		f.appendImage(img1);
		f.appendImage(img2);
		f.appendImage(img3);
	}

	{
		scope f = FileDb.fromFile(tmp_db_path);
		assert(equal(f.imageDataIterator(), [img1, img2, img3]));
	}

}

unittest {
	scope(exit) { remove(tmp_db_path); }
	auto img1 = imageFromFile(0, "test/cat_a1.jpg");
	auto img2 = imageFromFile(1, "test/cat_a2.jpg");
	auto img3 = imageFromFile(3, "test/small_png.png");

	{
		scope f = FileDb.fromFile(tmp_db_path, true);
		f.appendImage(img1);
		f.appendImage(img2);
		f.appendImage(img3);
	}

	{
		scope f = FileDb.fromFile(tmp_db_path);
		f.removeImage(1);
	}

	{
		scope f = FileDb.fromFile(tmp_db_path);
		assert(equal(f.imageDataIterator(), [img1, img2]));
	}

}
