module net.request;

import sig : ImageRes;
import types;
import magick_wand.colorspace : RGB;

struct RequestCreateFileDb {
	string db_path;
}

struct RequestLoadFileDb {
	bool create_if_not_exist = false;
	string db_path;
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
}

struct RequestRemoveImage {
	user_id_t database_id;
	user_id_t image_id;
}

struct RequestPing {}

struct RequestListDatabases {}

struct RequestVersion {}
