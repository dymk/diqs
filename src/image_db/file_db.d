module image_db.file_db;

/**
 * Represents an image database that can syncronize with the disk.
 */

import std.stdio : File, ErrnoException;
import std.typecons : Tuple;
import std.exception : enforce;

import types :
	image_id_t,
	coeffi_t,
	chan_t;

import sig :
	ImageData,
	ImageRes,
	ImageDC,
	IDImageData;

import image_db : BaseDB;
import consts : ImageArea, NumColorChans;

import dcollections.HashMap : HashMap;

/**
 * Database structure:
 * where N is the number of images in the database
 * - type     (bytes) |    name    |    description
 * - size_t       (4) | num_images | Number of images (N) in the database
 * - IDImageData      |
 */

class FileDB : BaseDB
{
	alias IdMap = HashMap!(image_id_t, image_id_t);

	struct IDImageSansSig
	{
		image_id_t user_id;
		ImageDC dc;
		ImageRes res;
	}

	struct Bucket
	{
		import std.algorithm :
		  stdRemove = remove,
		  sort,
		  countUntil,
		  SortedRange,
		  SwapStrategy;
		import std.range : assumeSorted;

		coeffi_t coeff;

		// Push an ID into the bucket
		size_t push(image_id_t id)
		{
			enforce(!has(id));
			m_mem_ids ~= id;
			m_sorted_mem_ids = sort(m_mem_ids);
			return length;
		}

		// Test if the bucket contains that ID
		bool has(image_id_t id)
		{
			return m_sorted_mem_ids.contains(id);
		}

		// Shorthand for remove and push
		void move(image_id_t from, image_id_t to)
		{
			remove(from);
			push(to);
		}

		// Remove an ID from the bucket
		bool remove(image_id_t id)
		{
			// Get the position of the ID
			auto pos = m_sorted_mem_ids.countUntil(id);
			if(pos == -1)
				return false;
			m_mem_ids = m_mem_ids.stdRemove(pos);
			m_sorted_mem_ids = m_mem_ids.assumeSorted();
			return true;
		}

		auto ids() @property    { return m_sorted_mem_ids; }
		auto length() @property { return m_mem_ids.length; }

	private:
		image_id_t[] m_mem_ids;
		SortedRange!(image_id_t[]) m_sorted_mem_ids;
	}

	/// Loads the database from the file in db_path
	this(string db_path)
	{
		m_user_mem_ids_map = new IdMap;
		m_user_file_ids_map = new IdMap;

		m_db_path = db_path;

		// Initialize buckets with the correct coeffs
		foreach(chan; 0..NumColorChans) {
			foreach(short b_index; 0..m_buckets[chan].length) {
				auto coeff = coeffForBucketIndex(b_index);
				m_buckets[chan][b_index] = Bucket(coeff);
			}
		}
	}

	bool load()
	{
		m_db_handle = File(m_db_path, "r");
		throw new Exception("not implemented");
		//return true;
	}

	bool save()
	{
		throw new Exception("not implemented");
	}

	override IDImageData addImage(ImageData imgdata)
	{
		immutable user_id = nextUserId();
		auto sig = imgdata.sig;
		auto dc = imgdata.dc;
		auto res = imgdata.res;

		immutable img = IDImageData(user_id, sig, dc, res);

		// populate the relevant buckets with that image's data
		foreach(byte chan; 0..sig.sigs.length)
		{
			auto bucket_chan = m_buckets[chan];
			foreach(coeffi_t coeff; sig.sigs[chan])
			{
				bucketForCoeff(coeff, chan).push(user_id);
			}
		}

		// append an ImageAddJob
		m_add_jobs ~= img;

		// Append the image's DC onto the memory array of DC data
		// and record its position in the array
		enforce(m_user_mem_ids_map.elemAt(user_id).empty,
			"Image with that ID is already held in memory!");
		m_mem_imgs ~= IDImageSansSig(user_id, img.dc, img.res);
		m_user_mem_ids_map[user_id] = m_mem_imgs.length - 1;

		return img;
	}

	auto numImages() @property { return m_mem_imgs.length; }

	/* Will implement this later
	bool removeImage(image_id_t user_id)
	{
		auto mem_idx_range = m_user_mem_ids_map.elemAt(user_id);
		enforce(!mem_idx_range.empty, "that id doesn't exist in this database");
		auto mem_idx = mem_idx.front;
		auto sig = m_mem_imgs[mem_idx];

		// Remove the image from all the buckets

		throw new Exception("not implemented");
	}*/
	short bucketIndexForCoeff(coeffi_t coeff)
	{
		assert(coeff != 0, "Coeff at 0 is a DC component; not a sig coeff");
		// Because there is no 0 bucket, shift
		// all bucekts > 0 down by 1
		if(coeff > 0)
			coeff--;
		coeff += ImageArea; // Eg bucket -16384 => 0
		return coeff;
	}

	/// Inverse of bucketIndexForCoeff
	/// Convert a bucket's index to a coefficient
	/// EG 0 => -16384
	coeffi_t coeffForBucketIndex(short index)
	{
		if(index >= ImageArea)
			index++;
		index -= ImageArea;
		return index;
	}

	ref Bucket bucketForCoeff(coeffi_t coeff, chan_t chan)
	{
		return m_buckets[chan][bucketIndexForCoeff(coeff)];
	}

	ref const auto buckets() @property
	{
		return m_buckets;
	}

private:
	// Path to the database file this is bound to
	scope string m_db_path;
	scope File m_db_handle;

	// Maps a user_id to its index in m_mem_imgs
	scope IdMap m_user_mem_ids_map;
	scope IDImageSansSig[] m_mem_imgs;

	// Maps a user_id to its location on the disk DB
	scope IdMap m_user_file_ids_map;

	// Coefficient buckets
	Bucket[(ImageArea*2)-1][NumColorChans] m_buckets;

	// Logs images being inserted and removed from the database
	// so when .save() is called, the in database file can
	// be synced with the state of the memory database
	alias ImageAddJob = IDImageData;
	alias ImageRmJob  = image_id_t;

	scope ImageAddJob[] m_add_jobs;
	scope ImageRmJob[]  m_rm_jobs;
}

version(unittest)
{
	import std.algorithm : equal;
	import std.stdio;
}

unittest {
	auto f = new FileDB("");
	assert(f.buckets[0][0].coeff == -16384);
}

unittest {
	auto f = new FileDB("");
	assert(f.bucketIndexForCoeff(-16384) == 0);
	assert(f.bucketIndexForCoeff(-16383) == 1);

	assert(f.bucketIndexForCoeff(-1) == 16383);
	assert(f.bucketIndexForCoeff(1) == 16384);
	assert(f.bucketIndexForCoeff(16384) == 32767);
}

unittest {
	auto f = new FileDB("");
	assert(f.coeffForBucketIndex(0) == -16384);
	assert(f.coeffForBucketIndex(16383) == -1);
	assert(f.coeffForBucketIndex(16384) == 1);
	assert(f.coeffForBucketIndex(32767) == 16384);
}

unittest {
	auto f = new FileDB("");
	auto i = ImageData.fromFile("test/cat_a1.jpg");
	assert(f.numImages() == 0);
	f.addImage(i);
	//assert(f.numImages() == 1);
}

unittest {
	auto f = new FileDB("nonexistant");
	bool thrown = false;
	try {
		f.load();
	} catch(ErrnoException e) {
		thrown = true;
	}
	assert(thrown);
}

unittest {
	auto c = new FileDB.IdMap;
	c[50] = 3;
	c[1] = 2;
	assert(!c.elemAt(1).empty);
	assert(c.elemAt(1).front == 2);
	assert(c.elemAt(2).empty);
}

unittest {
	auto b = FileDB.Bucket();
	b.push(1);
	b.push(2);
	assert(equal(b.ids, [1, 2]));
}

unittest {
	auto b = FileDB.Bucket();
	b.push(1);
	b.remove(1);
	uint[] empty = [];
	assert(equal(b.ids, empty));
}

unittest {
	auto b = FileDB.Bucket();
	foreach(i; 0..5)
		b.push(i);
	b.remove(1);
	assert(equal(b.ids, [0, 2, 3, 4]));
}

unittest {
	auto b = FileDB.Bucket();
	b.push(1);
	b.move(1, 2);
	assert(equal(b.ids, [2]));
}
