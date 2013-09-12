module image_db.file_db;

/**
 * Represents an image database that can syncronize with the disk.
 */

import std.typecons : Tuple;
import std.exception : enforce;
import std.container : Array;
import core.memory : GC;

import vibe.core.file :
  existsFile,
  openFile,
  FileMode,
  FileStream;

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

import image_db.base_db : BaseDb, IdGen;
import image_db.mem_db : MemDb;
import consts :
  ImageArea,
  NumColorChans,
  NumBuckets;

import query :
  QueryParams;

import persistence_layer.on_disk_persistence : OnDiskPersistence;

class FileDb : BaseDb
{

	static FileDb loadFromFile(string path, bool create_if_nonexistant = false)
	{
		return new FileDb(OnDiskPersistence.loadFromFile(path, create_if_nonexistant));
	}

	static FileDb createFromFile(string path)
	{
		return new FileDb(OnDiskPersistence.createFromFile(path));
	}

	this(OnDiskPersistence persist_layer) {
		this.persist_layer = persist_layer;
		this.m_mem_db = new MemDb(this.persist_layer.length);
		this.m_id_gen = new IdGen!user_id_t;

		m_mem_db.bucketSizeHint(persist_layer.bucketSizes());

		foreach(ref image; persist_layer.imageDataIterator()) {
			m_id_gen.saw(image.user_id);
			m_mem_db.addImage(image);
		}
	}

	user_id_t addImage(in ImageSigDcRes img) {
		user_id_t user_id = m_id_gen.next();
		auto id_img = ImageIdSigDcRes(user_id, img.sig, img.dc, img.res);
		return addImage(id_img);
	}

	user_id_t addImage(in ImageIdSigDcRes img) {
		m_id_gen.saw(img.user_id);

		auto ret = m_mem_db.addImage(img);
		queueAddJob(img);
		return ret;
	}

	auto getImage(user_id_t id) {
		return persist_layer.getImage(id);
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

	void close() {
		persist_layer.close();
	}

	~this() {
		save();
		close();
	}

	user_id_t nextId() {
		return m_id_gen.next();
	}

	auto query(QueryParams query) {
		return m_mem_db.query(query);
	}
	auto imageDataIterator() {
		return persist_layer.imageDataIterator();
	}

	auto path() {
		return persist_layer.path();
	}

	auto dirty() {
		return persist_layer.dirty();
	}

private:
	void queueAddJob(ImageIdSigDcRes img) {
		persist_layer.appendImage(img);
	}

	// Path to the database file this is bound to
	OnDiskPersistence persist_layer;
	MemDb m_mem_db;
	IdGen!user_id_t m_id_gen;
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
	scope f = FileDb.loadFromFile(tmp_db_path, true);
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
	scope f = FileDb.loadFromFile(tmp_db_path, true);
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
	scope f = FileDb.loadFromFile(tmp_db_path, true);
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
		scope f = FileDb.loadFromFile(tmp_db_path, true);
		f.addImage(img1);
		f.addImage(img2);
		f.addImage(img3);
	}

	{
		scope f = FileDb.loadFromFile(tmp_db_path);
		assert(equal(f.imageDataIterator(), [img1, img2, img3]));
	}

}

unittest {
	scope(exit) { remove(tmp_db_path); }
	auto img1 = imageFromFile(0, "test/cat_a1.jpg");
	auto img2 = imageFromFile(1, "test/cat_a2.jpg");
	auto img3 = imageFromFile(3, "test/small_png.png");

	{
		scope f = FileDb.loadFromFile(tmp_db_path, true);
		f.addImage(img1);
		f.addImage(img2);
		f.addImage(img3);
	}

	{
		scope f = FileDb.loadFromFile(tmp_db_path);
		f.removeImage(1);
	}

	{
		scope f = FileDb.loadFromFile(tmp_db_path);
		assert(equal(f.imageDataIterator(), [img1, img3]));
	}

}
