module net.request;

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
	string image_path;
	int num_results;
	bool ignore_color = false;
	bool is_sketch = false;
}

struct RequestAddImageFromPath {
	user_id_t db_id;

	bool generate_id = false;
	user_id_t image_id;

	string image_path;
}

struct RequestAddImageFromPixels {
	user_id_t db_id;

	bool generate_id = false;
	user_id_t image_id;

	ushort original_width;
	ushort original_height;
	RGB[] pixels;
}

struct RequestRemoveImage {
	user_id_t database_id;
	user_id_t image_id;
}

struct RequestPing {}

struct RequestListDatabases {}

struct RequestVersion {}
