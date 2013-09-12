module net.request;

import types;

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

struct RequestAddImageFromBlob {
	user_id_t db_id;

	// If generate_id is true, then a unique ID will be
	// generated for the user. Else, the ID provided by the
	// user will be tried to be used.
	bool generate_id = false;
	user_id_t image_id;

	// Image blob data.
	ubyte[] image_bytes;
}

struct RequestAddImageFromPath {
	user_id_t db_id;

	bool generate_id = false;
	user_id_t image_id;

	string image_path;
}

struct RequestRemoveImage {
	user_id_t database_id;
	user_id_t image_id;
}

struct RequestPing {}

struct RequestListDatabases {}

struct RequestVersion {}
