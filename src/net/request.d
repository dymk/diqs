module net.request;

import types;
import net.payload;

struct RequestLoadDbFile {
	static type = PayloadType.request_load_db_file;

	string path;
	bool create_if_not_exist;
}

struct RequestQueryFromFile {
	static type = PayloadType.request_query_from_file;

	string image_path;
	int num_results;
	bool ignore_color = false;
	bool is_sketch = false;
}

struct RequestAddImageFromFile {
	static type = PayloadType.request_add_image_from_file;

	string image_path;
}

struct RequestAddImageFromFileId {
	static type = PayloadType.request_add_image_from_file_id;

	string image_path;
	user_id_t user_id;
}

struct RequestRemoveImage {
	static type = PayloadType.request_remove_image;

	user_id_t user_id;
}
