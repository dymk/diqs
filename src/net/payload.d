module net.payload;

import std.exception : enforce, enforceEx;
import std.variant : Algebraic;
import std.format : format;
import std.array : join;
import std.traits : EnumMembers;

import vibe.core.net : TCPConnection;
import vibe.core.log;

import util : snakeToPascalCase, pascalToSnakeCase;
import net.common;
public import net.response;
public import net.request;
public import net.db_info;

/**
 * The basics of a request/response cycle:
 * A client begins by connecting and sending a Payload, usually with a
 * Request prefix, and a server responds with a Payload, usually with
 * a Response prefix. Clients and servers resemble a peer to peer
 * configuration, because either can send a request or a response, and
 * the other side of the connection can decide what types of payloads
 * it responds to and with.
 *
 * The Nitty Gritty (Implementing a Peer):
 * The Payload variants are different Struct types. They fall into
 * two categories: Simple, and Rich. Simple Payloads have zero members,
 * and are typically used to signal something like the request was
 * successful. Rich payloads have at least one member, and are used
 * to transfer a variable amount of information between the peers.
 *
 * How a payload is serialized:
 *
 * If the Payload is Simple:
 * Full Payload size: 2 bytes
 * -------------------------------------------------
 * PayloadType | 2 bytes | the variant's type
 * -------------------------------------------------
 *
 * If the Payload is Rich:
 * Full Payload size: 6 + N bytes
 * -------------------------------------------------
 * PayloadType | 2 bytes | the variant's type
 * uint        | 4 bytes | Length of the payload (N)
 * ubyte[]     | N bytes | Actual payload data
 * -------------------------------------------------
 * where ubyte[] is the payload data as a raw ubyte array of
 * N length. This is casted into the variant indicated by
 * PayloadType, and returned as a Payload (the
 * readPayload() function).
 */

/**
 * A list of all payload types, for both requests and responses.
 * This exists to disambiguate between all payloads sent, so a
 * request will never have the same type header (the first uint sent)
 * as a response.
 * PayloadVersion is updated when a PayloadType is added or a Payload
 * variant is modified.
 */
enum uint PayloadVersion = 1;
enum PayloadType : ushort {
	response_image_added,
	response_db_info,
	response_success,
	response_failure,
	response_pong,
	response_version,
	response_list_databases,

	request_create_file_db,
	request_query_from_path,
	request_list_databases,
	request_load_file_db,
	request_add_image_from_path,
	request_add_image_from_blob,
	request_remove_image,
	request_version,
	request_ping
}


string[] getPayloadTypesStrings() {
	string[] ret;
	foreach(member; __traits(allMembers, PayloadType)) {
		ret ~=  member.snakeToPascalCase();
	}
	return ret;
}

mixin(`
	alias Payload = Algebraic!(` ~ getPayloadTypesStrings().join(", ") ~ `);
`);

// Expands to something like:
//alias Payload = Algebraic!(
//	ResponseDbInfo,
//	RequestAddImagePathToDb);

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

	uint length;
	ubyte[] buffer;
	scope(exit) { GC.free(buffer.ptr); }

	Payload ret;

	final switch(type) with(PayloadType) {

		foreach(member; __traits(allMembers, PayloadType)) {
			mixin("mixin(PayloadCase!(" ~ member ~ ", " ~ member.snakeToPascalCase() ~ "));");
		}

		// Generates something like:
		//mixin(PayloadCase!(response_db_info, ResponseDbInfo));

		// Which in turn expands to something like:

		//case response_db_info:
		//	ResponseDbInfo variant;
		//	length = conn.readValue!uint();
		//	buffer = new ubyte[](length);

		//	conn.read(buffer);
		//	msgpack.unpack(buffer, variant);

		//	ret = variant;
		//	break;

		// Or, if it's a zero-member variant, something like:

		//case response_success:
		//	ret = ResponseSuccess();
		//	break;
	}

	return ret;
}

template PayloadCase(alias PayloadType type, alias Variant)
{
	static if(Variant.tupleof.length == 0)
	{
		// A Payload variant with no members
		enum PayloadCase = `
			case ` ~ type.stringof ~ `:
				ret = ` ~ Variant.stringof ~ `();
				break;`;
	}
	else
	{
		// A Payload variant with one or more members
		enum PayloadCase = `
			case ` ~ type.stringof ~  `:
				` ~ Variant.stringof ~ ` variant;
				length = conn.readValue!uint();
				buffer = new ubyte[](length);

				conn.read(buffer);
				msgpack.unpack(buffer, variant);

				ret = variant;
				break;`;
	}
}

void writePayload(P)(TCPConnection conn, P request)
{

	mixin(q{
		conn.writeValue!PayloadType(PayloadType.} ~ P.stringof.pascalToSnakeCase() ~ q{);
	});

	// Expands to something like this, if P is ResponseSuccess:
	// conn.writeValue!PayloadType(PayloadType.response_success);

	static if(P.tupleof.length != 0)
	{
		auto packed = msgpack.pack(request);
		scope(exit) { GC.free(packed.ptr); }

		// Hopefully the server doens't send an object over 4gb
		uint length = cast(uint)packed.length;

		conn.writeValue!uint(length);
		conn.write(packed);
	}
}
