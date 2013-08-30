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

import query :
  QueryParams;

import persistence_layer.persistence_layer : PersistenceLayer;
import persistence_layer.on_disk_persistence : OnDiskPersistence;

class FileDb : BaseDb
{

	static FileDb fromFile(string path, bool create_if_nonexistant = false)
	{
		return new FileDb(OnDiskPersistence.fromFile(path, create_if_nonexistant));
	}

	this(PersistenceLayer persist_layer) {
		this.persist_layer = persist_layer;
		this.m_mem_db = new MemDb(this.persist_layer.length);

		m_mem_db.bucketSizeHint(persist_layer.bucketSizes());

		foreach(ref image; persist_layer.imageDataIterator()) {
			m_mem_db.addImage(image);
		}
	}

	user_id_t addImage(in ImageIdSigDcRes img) {
		auto ret = m_mem_db.addImage(img);
		queueAddJob(img);
		return ret;
	}

	uint numImages() {
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
			if(!ret1.sameAs(ret2)) {
				writeln("PLayer and MemDB returned different signatures; oops!");
				writeln("PLayer returned: ");
				writeln(ret1);
				writeln("MemDB returned: ");
				writeln(ret2);

				writeln("IDs (same: ", ret1.user_id == ret2.user_id, ")");

				writeln("DCs (same: ", ret1.dc == ret2.dc, ")");
				writeln(ret1.dc);
				writeln(ret2.dc);

				writeln("Resolutions: (same: ", ret1.res == ret2.res, ")");
				writeln(ret1.res);
				writeln(ret2.res);

				writeln("Sigs (same: ", ret1.sig.sameAs(ret2.sig), ")");
				//writeln(ret1.sig);
				//writeln(ret2.sig);

				assert(false);
			}
		}

		return ret1;
	}

	void save() {
		persist_layer.save();
	}

	~this() {
		persist_layer.destroy();
	}

	auto query(QueryParams query) {
		return m_mem_db.query(query);
	}
	auto imageDataIterator() {
		return persist_layer.imageDataIterator();
	}

private:
	void queueAddJob(ImageIdSigDcRes img) {
		persist_layer.appendImage(img);
	}

	// Path to the database file this is bound to
	string m_db_path;
	PersistenceLayer persist_layer;
	MemDb m_mem_db;
}

version(unittest)
{
	import std.algorithm : equal;
	import std.stdio;
	import std.file : remove;

	import sig : imageFromFile;

	static string tmp_db_path = "test/tmp_db_path.db";
}

unittest {
	scope(exit) { remove(tmp_db_path); }
	scope f = FileDb.fromFile(tmp_db_path, true);
	auto img1 = imageFromFile(0, "test/cat_a1.jpg");
	auto img2 = imageFromFile(1, "test/cat_a1.jpg");

	f.addImage(img1);
	f.addImage(img2);
	f.save();
	assert(f.numImages() == 2);

	auto ret = f.removeImage(0);
	assert(ret == img1);

	assert(f.numImages() == 1);
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

	f.addImage(img1);
	f.addImage(img2);

	bool thrown = false;
	try {
		f.imageDataIterator();
	} catch(OnDiskPersistence.DatabaseDirtyException e) {
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
		f.addImage(img1);
		f.addImage(img2);
		f.addImage(img3);
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
		f.addImage(img1);
		f.addImage(img2);
		f.addImage(img3);
	}

	{
		scope f = FileDb.fromFile(tmp_db_path);
		f.removeImage(1);
	}

	{
		scope f = FileDb.fromFile(tmp_db_path);
		assert(equal(f.imageDataIterator(), [img1, img3]));
	}

}
