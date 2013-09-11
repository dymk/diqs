module net.db_info;

import types;
import image_db.all : BaseDb, FileDb, MemDb;

struct DbInfo {
	enum Type {
		Mem,
		File
	}

	// Probably not the best way to transfer database info, but it
	// greatly simplifies ease of serializing database info for multiple
	// different types of databases in a peer-agnostic way.
	Type type;
	user_id_t id;
	uint num_images;
	bool _dirty;
	string _path;

	bool dirty() @property {
		if(type != Type.File)
			assert(false);

		return _dirty;
	}

	string path() @property {
		if(type != Type.File)
			assert(false);

		return _path;
	}

	this(user_id_t id, MemDb db) {
		this(id, cast(BaseDb) db);
		this.type = Type.Mem;
	}

	this(user_id_t id, FileDb db) {
		this(id, cast(BaseDb) db);
		this.type = Type.File;

		this._dirty = db.dirty();
		this._path = db.path();
	}

private:
	this(user_id_t id, BaseDb db) {
		this.type = type;

		this.num_images = db.numImages();
	}
}
