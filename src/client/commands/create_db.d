module client.commands.create_db;

import client.commands.common;
import net.common;
import types;

import std.getopt;

int main(string[] args)
{
	string path, type;
	bool create = false, help = false;

	try
	{
		getopt(args,
			"path|p", &path,
			"type|t", &type,
			"help|h", &help);
	}
	catch(Exception e)
	{
		printFailure(ErrorCode.InvalidOptions);
		return ErrorCode.InvalidOptions;
	}

	if(help || type == "")
	{
		printHelp();
		return 0;
	}

	if(type != "mem" && type != "level")
	{
		stderr.writeln("type must be 'mem' or 'level'");
		printFailure(ErrorCode.InvalidOptions);
		return ErrorCode.InvalidOptions;
	}

	if(type == "level" && path == "")
	{
		stderr.writeln("type 'level' needs a path");
		printFailure(ErrorCode.InvalidOptions);
		return ErrorCode.InvalidOptions;
	}

	string host;
	ushort port;
	Socket conn;
	if(int ret = connectToServerCommon(args, host, port, conn) != 0)
	{
		return ret;
	}

	if(type == "level")
	{
		conn.writePayload(RequestCreateLevelDb(path));
	}
	else
	{
		conn.writePayload(RequestCreateMemDb());
	}

	conn.readPayload().tryVisit!(
		commonHandleResponseFailure,
		(ResponseDbInfo resp)
		{
			printDbInfo(resp.db);
		}
	);

	return 0;
}

void printHelp()
{
	writeln(`
  Usage: create_db [Options...]

  Options:
    --help | -h
      Displays this help message

    --type=TYPE | -tTYPE
      Creates a TYPE database, where TYPE is 'mem' or 'level'

    [--path=PATH | -pPATH]
      If TYPE is 'level', then the path to create the leveldb at`);
	printCommonHelp();
}