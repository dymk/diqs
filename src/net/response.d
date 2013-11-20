module net.response;

import sig;
import types;
import image_db.mem_db : MemDb;
import image_db.file_db : FileDb;
import net.db_info : DbInfo;
import net.common;

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

struct ResponseServerShutdown {}

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
		NonExistantFile,
		InvalidImage,
		CantResizeImage,
		CantExportPixels,

		// FileDb file exceptions
		DbFileAlreadyExists,
		DbFileNotFound,

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

	string versionString()
	{
		return format("%d.%d.%d", major, minor, patch);
	}
}

struct ResponseListDatabases {
	DbInfo[] databases;
}

struct ResponseQueryResults {
	struct QueryResult {
		user_id_t user_id;
		float similarity;
		ImageRes res;
	}

	QueryResult[] results;
}
