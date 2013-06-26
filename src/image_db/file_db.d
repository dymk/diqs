module image_db.file_db;

/**
 * Represents an image database that can syncronize with the disk.
 */

import std.stdio : File;
import std.typecons : Tuple;

import types : image_id_t, ImageData, IDImageData;
import image_db : BaseDB;

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

	/// Loads the database from the file in db_path
	this(string db_path)
	{
		m_user_internal_ids = new IdMap;
		m_db_path = db_path;
	}

	bool load()
	{
		throw new Exception("not implemented");
	}

	bool save()
	{
		throw new Exception("not implemented");
	}

	image_id_t addImage(ImageData imgdata)
	{
		auto user_id = nextUserId();
		throw new Exception("not implemented");
	}

	bool removeImage(image_id_t)
	{
		throw new Exception("not implemented");
	}

	/// Returns the next unique ID for an image
	/// User facing IDs are not expected to be
	/// continuous; there's an internal ID which can
	/// be changed on image removal.
	image_id_t nextUserId()
	{
		return m_next_user_id++;
	}

private:
	// Path to the database file this is bound to
	string m_db_path;

	// Maps a user_id to an internally used ID
	 IdMap m_user_internal_ids;

	// The next highest user facing ID in the database (highest found + 1)
	image_id_t m_next_user_id = 0;

	// Logs images being inserted and removed from the database
	// so when .save() is called, the in database file can
	// be synced with the state of the memory database
	alias ImageAddJob = Tuple!(image_id_t, IDImageData);
	alias ImageRmJob  = image_id_t;
	ImageAddJob[] m_add_jobs;
	ImageRmJob[]  m_rm_jobs;
}

unittest {
	auto f = new FileDB("nonexisant_file.db");
	assert(f.nextUserId() == 0);
	assert(f.nextUserId() == 1);
	assert(f.nextUserId() == 2);
}
