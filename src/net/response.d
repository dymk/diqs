module net.response;

import types;
import net.payload;

struct ResponseDbInfo {
	static type = PayloadType.response_db_info;

	string path;
	uint num_images;
}

struct ResponseSuccess {
	static type = PayloadType.response_success;
}

struct ResponseFailure {
	static type = PayloadType.response_failure;

	uint code;
}

struct ResponsePong {
	static type = PayloadType.response_pong;
}
