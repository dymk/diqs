module net.common;

import std.exception : enforce, enforceEx;
import std.variant : Algebraic;
import std.conv : to;
import std.string : format;
import std.socket : Socket;
import core.memory : GC;

class NetworkException : Exception
{
  this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
};

final class ConnectionClosedException : NetworkException
{
  this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
};

bool writeValue(Value)(Socket conn, Value value) {
	ubyte[Value.sizeof] val;
	val = *(cast(ubyte[Value.sizeof]*)(&value));
	return conn.send(val[]) == Value.sizeof;
}

Value readValue(Value)(Socket conn) {
	ubyte[Value.sizeof] ret_arr;
  auto len_recieved = conn.receive(ret_arr[]);

  if(len_recieved == 0)
  {
    throw new ConnectionClosedException("Recieved zero bytes from the connection");
  }

	enforce(len_recieved == Value.sizeof,
    "Didn't recieve right length (got " ~ to!string(len_recieved) ~ " expected " ~ to!string(Value.sizeof));
	return *(cast(Value*)ret_arr.ptr);
}
