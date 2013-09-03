module net.payload;

import std.exception : enforce, enforceEx;
import std.variant : Algebraic;
import std.format : format;

import vibe.core.net : TCPConnection;
import vibe.core.log;

import net.common;
public import net.response;
public import net.request;


/**
 * A list of all payload types, for both requests and responses.
 * This exists to disambiguate between all payloads sent, so a
 * request will never have the same  type header (the first uint sent)
 * as a response.
 */
enum PayloadType {
		response_db_info,
		response_success,
		response_failure,

		request_load_db_file,
		request_query_from_file,
		request_add_image_from_file,
		request_add_image_from_file_id,
		request_remove_image
}

alias Payload = Algebraic!(
	ResponseDbInfo,
	ResponseSuccess,
	ResponseFailure,

	RequestLoadDbFile,
	RequestQueryFromFile,
	RequestAddImageFromFile,
	RequestAddImageFromFileId,
	RequestRemoveImage);

class PayloadException : Exception {
	this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
};
final class InvalidPayloadException : PayloadException {
	this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
};


// A generic function for reading an algebraic datatype from
// a stream. determine_payload does the work of returning
// a Payload variant for the PayloadType read from the TCPConnection,
// given the buffer that was read from the stream. It should be
// implemented as a final switch in most cases.

// TODO: make TCPConnection an InputStream instead?
Payload readPayload(TCPConnection conn) {
	auto type = conn.readValue!PayloadType;
	if(type < PayloadType.min || type > PayloadType.max) {
		throw new InvalidPayloadException(format("Invalid PayloadType value sent: %d", cast(uint)type));
	}

	auto length = conn.readValue!uint;
	ubyte[] buffer;
	scope(exit) { GC.free(buffer.ptr); }
	if(length) {
		buffer = new ubyte[](length);
		conn.read(buffer);
	}

	Payload ret;

	final switch(type) with(PayloadType) {
		mixin(PayloadCase!(response_db_info, ResponseDbInfo));
		mixin(PayloadCase!(response_success, ResponseSuccess));
		mixin(PayloadCase!(response_failure, ResponseFailure));

		mixin(PayloadCase!(request_load_db_file, RequestLoadDbFile));
		mixin(PayloadCase!(request_query_from_file, RequestQueryFromFile));
		mixin(PayloadCase!(request_add_image_from_file, RequestAddImageFromFile));
		mixin(PayloadCase!(request_add_image_from_file_id, RequestAddImageFromFileId));
		mixin(PayloadCase!(request_remove_image, RequestRemoveImage));
	}

	return ret;
}

template PayloadCase(alias PayloadType type, alias Variant)
{
	static if(Variant.tupleof.length == 0)
	{
		enum PayloadCase = `
			case ` ~ type.stringof ~ `:
				ret = ` ~ Variant.stringof ~ `();
				break;`;
	}
	else
	{
		enum PayloadCase = `
			case ` ~ type.stringof ~  `:
				` ~ Variant.stringof ~ ` variant;
				msgpack.unpack(buffer, variant);
				ret = variant;
				break;`;
	}
}

void writePayload(P)(TCPConnection conn, P request)
if(is(typeof(P.type) == PayloadType))
{

	conn.writeValue!uint(P.type);

	static if(P.tupleof.length != 0)
	{
		auto packed = msgpack.pack(request);
		scope(exit) { GC.free(packed.ptr); }

		uint length = packed.length;

		conn.writeValue!uint(length);
		conn.write(packed);
	}
	else
	{
		conn.writeValue!uint(0);
	}
}
