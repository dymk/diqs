module net.db_info;

import types;
import image_db.base_db;
import image_db.mem_db;
import image_db.persisted_db;

struct DbInfo {
	enum Type : int {
		Mem,
		Persisted
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
		enforce(type == Type.Persisted);

		return _dirty;
	}

	string path() @property {
		enforce(type == Type.Persisted);

		return _path;
	}

	this(user_id_t id, MemDb db) {
		this(id, cast(BaseDb) db);
		this.type = Type.Mem;
	}

	this(user_id_t id, PersistedDb db) {
		this(id, cast(BaseDb) db);
		this.type = Type.Persisted;

		this._dirty = db.dirty();
		this._path = db.path();
	}

private:
	this(user_id_t id, BaseDb db) {
		this.id = id;
		this.num_images = db.numImages();
	}
}
