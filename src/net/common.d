module net.common;

import types;
import net.request;
import net.response;

import vibe.core.net : TCPConnection;
import vibe.core.log;

import std.exception : enforce, enforceEx;
import std.variant : Algebraic;
import std.conv : to;
import std.format : format;
import core.memory : GC;

import msgpack;

static immutable DefaultHost = "127.0.0.1";
            enum DefaultPort = 9548;

void writeValue(Value)(TCPConnection conn, Value value) {
	ubyte[Value.sizeof] val;
	val = *(cast(ubyte[Value.sizeof]*)(&value));
	conn.write(val[]);
}

Value readValue(Value)(TCPConnection conn) {
	ubyte[Value.sizeof] ret_arr;
	conn.read(ret_arr[]);
	return *(cast(Value*)ret_arr.ptr);
}
