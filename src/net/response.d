module net.response;

import sig;
import types;
import image_db.mem_db : MemDb;
import image_db.persisted_db : PersistedDb;
import net.db_info : DbInfo;
import net.common;

struct ResponseDbInfo {
	this(user_id_t id, MemDb _db) {
		this.db = DbInfo(id, _db);
	}

	this(user_id_t id, PersistedDb _db) {
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
		DbNotLoaded,
		DbNonexistant,

		// Image signature generation errors
		NonExistantFile,
		InvalidImage,
		CantResizeImage,
		CantExportPixels,

		// PersistedDb file exceptions
		DbFileAlreadyExists,
		DbFileNotFound,

		// Signature insertion into DB errors
		AlreadyHaveId,

		// The payload sent by the client isn't known (or implemented)
		UnknownPayload,

		// The operation attempted on this DB isn't supported
		UnsupportedDbOperation,

		// All else
		UnknownException
	}

	Code code;
}

struct ResponseImageAddedBatch {
	// A struct that represents an image added in a batch operation
	// There isn't a guaretnee what order the images will be added,
	// so the path of the image is included along with the image's
	// ID

	user_id_t db_id;
	user_id_t image_id;
	string image_path;
}

struct ResponseFailureBatch {
	// Similar idea as ResponseImageAddedBatch, so the path of the image can be
	// associated with the failure code why it failed to be added to the db

	user_id_t db_id;
	string image_path;
	ResponseFailure.Code code;
}

struct ResponseSuccessBatch {
	// Sent after all of the images in a batch operation have been added
	// to the database

	user_id_t db_id;

	// The number of images added to the database (images in the directory
	// minus the number of failures)
	int num_images_added;

	// The number of failures
	int num_failures;
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
	}

	// How long the query took to perform
	long duration;

	// Each individual query result
	QueryResult[] results;
}
