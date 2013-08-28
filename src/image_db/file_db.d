module image_db.file_db;

/**
 * Represents an image database that can syncronize with the disk.
 */

import std.typecons : Tuple;
import std.exception : enforce;
import std.container : Array;
import std.file : exists;

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

import image_db.file_db_io : FileDbIo;

class FileDB : BaseDb
{

	/// Loads the database from the file in db_path
	this(string db_path)
	{
		this.m_mem_db = new MemDb();
	}

	bool load(bool create_if_nonexistant = true)
	{
		FileDbIo db = FileDbIo.load(m_db_path, create_if_nonexistant);
		m_mem_db.bucketSizeHint(*db.bucket_sizes);

		return true;
	}

	user_id_t addImage(in ImageIdSigDcRes img) {
		auto ret = m_mem_db.addImage(img);
		queueAddJob(img);
		return ret;
	}

	size_t numImages() {
		return m_mem_db.numImages();
	}

	ImageIdSigDcRes* removeImage(user_id_t id) {
		return m_mem_db.removeImage(id);
	}

private:
	void queueAddJob(ImageIdSigDcRes img) {
		m_add_jobs.insert(img);
	}

	// Path to the database file this is bound to
	string m_db_path;
	FileDbIo handle;
	MemDb m_mem_db;

	alias ImageAddJob = ImageIdSigDcRes;
	alias ImageRmJob  = user_id_t;

	Array!ImageAddJob m_add_jobs;
	Array!ImageRmJob  m_rm_jobs;
}

version(unittest)
{
	import std.algorithm : equal;
	import std.stdio;
}

unittest {
	auto f = new FileDB("");
	auto i = ImageSigDcRes.fromFile("test/cat_a1.jpg");
	assert(f.numImages() == 0);
	//f.addImage(i);
	//assert(f.numImages() == 1);
}
