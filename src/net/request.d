module net.request;

import sig : ImageRes;
import types;
import magick_wand.colorspace : RGB;

struct RequestCreateFileDb {
	string db_path;
}

struct RequestLoadFileDb {
	string db_path;
	bool create_if_not_exist = false;
}

struct RequestQueryFromPath {
	user_id_t db_id;

	string image_path;
	int num_results;

	bool ignore_color = false;
	bool is_sketch = false;
}

struct RequestAddImageFromPath {
	user_id_t db_id;

	bool use_image_id = false;
	user_id_t image_id;

	string image_path;

	// Save the database after the image has been added
	// Make false to keep the DB dirty (e.g., not syced with
	// the disk)
	bool flush_db_after_add = true;
}

struct RequestAddImageFromPixels {
	user_id_t db_id;

	bool use_image_id = false;
	user_id_t image_id;

	// Original width/height if the image was
	// resized on the client
	ImageRes original_res;

	// Actual dimentions of the pixels sent over
	ImageRes pixels_res;

	RGB[] pixels;

	// See RequestAddImageFromPath
	bool flush_db_after_add = true;
}

struct RequestAddImageBatch {
	user_id_t db_id;

	// Folder to add images from
	string folder;

	// Flush the database after each set of this number of images are added
	int flush_per_added;
}

struct RequestRemoveImage {
	user_id_t database_id;
	user_id_t image_id;
}

struct RequestFlushDb {
	user_id_t db_id;
}

struct RequestPing {}

struct RequestListDatabases {}

struct RequestVersion {}

struct RequestServerShutdown {}
