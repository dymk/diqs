module net.response;

import types;
import image_db.all : MemDb, FileDb;
import net.db_info : DbInfo;

struct ResponseDbInfo {
	this(user_id_t id, MemDb _db) {
		this.db = DbInfo(id, _db);
	}

	this(user_id_t id, FileDb _db) {
		this.db = DbInfo(id, _db);
	}

	DbInfo db;
}

struct ResponseSuccess {}

struct ResponseImageAdded {
	user_id_t db_id;
	uint num_images;

	user_id_t user_id;
}

struct ResponseFailure {
	uint code;
}

struct ResponsePong {}

struct ResponseVersion {
	int major;
	int minor;
	int patch;
}

struct ResponseListDatabases {
	DbInfo[] databases;
}
