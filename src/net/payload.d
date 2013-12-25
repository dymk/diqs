module net.payload;

import msgpack;

import std.exception : enforce, enforceEx;
import std.variant;
import std.string : format;
import std.array : join;
import std.algorithm;
import std.socket;
import std.stdio;

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
enum uint PayloadVersion = 2;
enum PayloadType : ushort {
	response_pong,
	response_db_info,
	response_success,
	response_failure,
	response_version,
	response_image_added,
	response_list_databases,
	response_query_results,
	response_success_batch,
	response_failure_batch,
	response_server_shutdown,
	response_image_added_batch,

	request_add_image_from_pixels,
	request_add_image_from_path,
	request_add_image_batch,
	request_server_shutdown,
	request_query_from_path,
	request_list_databases,
	request_create_level_db,
	request_load_level_db,
	request_create_mem_db,
	request_remove_image,
	request_close_db,
	request_flush_db,
	request_version,
	request_ping
}

string[] getPayloadTypesStrings()
{
	string[] ret;
	foreach(member; __traits(allMembers, PayloadType)) {
		ret ~=  member.snakeToPascalCase();
	}
	return ret;
}

/*
 * Expands to something like:
 *  alias Payload = Algebraic!(
 *	  ResponseDbInfo,
 *    ... (all the other response/request types)
 *	  RequestPing);
 */
mixin(`
	alias Payload = Algebraic!(` ~ getPayloadTypesStrings().join(", ") ~ `);
`);


class PayloadException : Exception {
	this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
};
final class InvalidPayloadException : PayloadException {
	this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
};
final class PayloadSocketExecption : PayloadException {
	this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
};
final class PayloadSocketClosedException : PayloadException {
	this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
};


// A generic function for reading an algebraic datatype from
// a stream. determine_payload does the work of returning
// a Payload variant for the PayloadType read from the Socket,
// given the buffer that was read from the stream. It should be
// implemented as a final switch in most cases.

// TODO: make Socket an InputStream instead?
Payload readPayload(Socket conn) {
	auto type = conn.readValue!PayloadType;
	if(type < PayloadType.min || type > PayloadType.max) {
		throw new InvalidPayloadException(format("Invalid PayloadType value sent: %d", cast(uint)type));
	}

	uint length;
	ubyte[] buffer;
	uint buffer_pos;
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

private template PayloadCase(alias PayloadType type, alias Variant)
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

				while(buffer_pos < length)
				{
					buffer_pos += conn.receive(buffer[buffer_pos .. $]);
				}

				assert(buffer_pos == length);
				msgpack.unpack(buffer, variant);

				ret = variant;
				break;`;
	}
}

/**
 * writePayload writes a given Payload type,
 */
void writePayload(P)(Socket conn, P payload)
{

	static if(is(P == Payload))
	{
		// A Payload type was passed in, match on it and call a
		// specialized writePayload

		// Expands to a list of lambdas which call a specialized writePayload
		// for each differnet Payload variant
		const string payloadHandlers = getPayloadTypesStrings().map!(
			(payload_type_str) {
				return "(" ~ payload_type_str ~ " p) { conn.writePayload!" ~ payload_type_str ~ "(p); } ";
			}
		)().join(", ");

		// Pass that list into visit!()
		mixin("payload.visit!(" ~ payloadHandlers ~ ")();");
	}
	else
	{
		// A Payload variant was directly passed in, figure out how to serialize
		// it

		// Send over the payload type header (2 bytes)
		// Expands to something like this, if P is ResponseSuccess:
		// conn.writeValue!PayloadType(PayloadType.response_success);
		mixin(
			"conn.writeValue!PayloadType(PayloadType." ~
			P.stringof.pascalToSnakeCase() ~
			");");

		static if(P.tupleof.length != 0)
		{
			// The payload has members; serialize and send those
			import std.traits;

			auto packed = msgpack.pack(payload);
			scope(exit) { GC.free(packed.ptr); }

			// Hopefully the server doens't send an object over 4gb
			uint length = cast(uint)packed.length;
			uint sent_pos = 0;

			conn.writeValue!uint(length);
			while(sent_pos < length)
			{
				auto bytes_sent = conn.send(packed[sent_pos .. $]);
				if(bytes_sent == Socket.ERROR)
				{
					if(conn.isAlive())
					{
						auto err_text = conn.getErrorText();
						conn.close();
						throw new PayloadSocketExecption(err_text);
					}
					else
					{
						throw new PayloadSocketClosedException("connection was closed");
					}
				}
				sent_pos += bytes_sent;
			}

			enforceEx!PayloadSocketExecption(sent_pos == length,
				format("sent: %d, actual: %d", sent_pos, length));
		}

	}
}

// Simple payload passing
unittest
{
	auto pair = socketPair();
	scope(exit) { foreach(p; pair) p.close(); }

	pair[0].writePayload(Payload(ResponseSuccess()));

	assert(pair[1].readPayload() == Payload(ResponseSuccess()));
}

// Connections being closed.
unittest
{
	auto pair = socketPair();
	scope(exit) { foreach(p; pair) p.close(); }

	pair[0].close();

	bool thrown = false;
	try
	{
		pair[1].readPayload();
	}
	catch(ConnectionClosedException)
	{
		thrown = true;
	}

	assert(thrown);
}


// Complex Payloads being passed
unittest
{
	auto pair = socketPair();
	scope(exit) { foreach(p; pair) p.close(); }

	pair[0].writePayload(Payload(ResponseVersion(1, 2, 3)));

	assert(pair[1].readPayload() == Payload(ResponseVersion(1, 2, 3)));
}

// Large payloads being passed
unittest
{
	import magick_wand.colorspace : RGB;
	import core.thread : Thread;

	auto pair = socketPair();
	scope(exit) { foreach(p; pair) p.close(); }

	foreach(p; pair) p.blocking = true;

	RequestAddImageFromPixels req;

	req.pixels = new RGB[](1024 * 1024 * 3); // 3MB "image"

	foreach(index, ref px; req.pixels)
	{
		ubyte val = index % ubyte.max;
		px = RGB(val, val, val);
	}

	auto sender = new Thread(() {
		pair[0].writePayload(Payload(req));
	});
	sender.start();

	auto resp = pair[1].readPayload().get!RequestAddImageFromPixels();

	foreach(index, px; resp.pixels)
	{
		ubyte val = index % ubyte.max;
		assert(px == RGB(val, val, val));
	}

	sender.join();
}
