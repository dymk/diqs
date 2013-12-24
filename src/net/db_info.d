module net.db_info;

import types;
import image_db.all;

struct DbInfo {
	enum Type : int {
		Mem,
		Persistable
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
		enforce(type == Type.Persistable);

		return _dirty;
	}

	string path() @property {
		enforce(type == Type.Persistable);

		return _path;
	}

	this(user_id_t id, MemDb db) {
		this(id, cast(BaseDb) db);
		this.type = Type.Mem;
	}

	this(user_id_t id, PersistableDb db) {
		this(id, cast(BaseDb) db);
		this.type = Type.Persistable;

		this._dirty = db.dirty();
		this._path = db.path();
	}

private:
	this(user_id_t id, BaseDb db) {
		this.id = id;
		this.num_images = db.numImages();
	}
}
