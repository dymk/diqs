module client.commands.common;

public {
	import consts;

	import net.db_info;
	import net.payload;
	import client.util;

	import std.stdio;
	import std.variant : tryVisit;
	import std.socket;
	import std.array;
	import std.conv : to;
	import std.getopt : getopt;
}

void printFailure(ErrorCode code, string err_str = "f")
{
	writefln("%s::%d::%s", err_str, code, code);
}

void printDbInfo(DbInfo info)
{
	writefln("s::%d::%d::%d::%d",
		info.id, info.flags, info.type, info.num_images);
}

template FatalError(ErrorCode e)
{
	enum FatalError = q{
		printFailure(e);
		return e;
	}.replace("__e", e.to!string);
}

int connectToServerCommon(ref string[] args, out string host, out ushort port, out Socket conn)
{
	port = DefaultPort;
	host = DefaultHost;

	try
	{
		getopt(args,
			"host|H", &host,
			"port|P", &port);
	}
	catch(Exception e)
	{
		mixin FatalError!(ErrorCode.InvalidOptions);
	}

	try
	{
		conn = connectToServer(host, port);
	}
	catch(SocketOSException e)
	{
		mixin FatalError!(ErrorCode.ConnectionError);
	}

	return 0;
}

void printCommonHelp()
{
	writeln(`
    --host=HOST | -HHOST = 127.0.0.1
      Connect to the DIQS server at HOST

    --port=PORT | -PPORT = 9548
      Connect to the server on port PORT`);
}