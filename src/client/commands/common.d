module client.commands.common;

public {
	import consts;

	import net.db_info;
	import net.payload;
	import client.util;

	import std.stdio;
	import std.variant : tryVisit;
	import std.socket;
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

mixin template FatalError(ErrorCode e)
{
	printFailure(e);
	return e;
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
