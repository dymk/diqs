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
	user_id_t image_id;
}

struct ResponseFailure {
	enum Code : ubyte {

		// Loaded database errors
		DbAlreadyLoaded,
		DbNotFound,

		// Image signature generation errors
		CantOpenFile,
		InvalidImage,
		CantResizeImage,
		CantExportPixels,

		// Signature insertion into DB errors
		AlreadyHaveId,

		// All else
		UnknownException
	}

	Code code;
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
