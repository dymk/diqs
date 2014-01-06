module client.commands.load_db;

import client.commands.common;
import net.common;
import types;

import std.getopt;

int main(string[] args)
{
	string path;
	bool create = false, help = false;

	try
	{
		getopt(args,
			"path|p", &path,
			"create|c", &create,
			"help|h", &help);
	}
	catch(Exception e)
	{
		printFailure(ErrorCode.InvalidOptions);
		return ErrorCode.InvalidOptions;
	}

	if(help || path == "")
	{
		printHelp();
		return 0;
	}

	string host;
	ushort port;
	Socket conn;

	if(int ret = connectToServerCommon(args, host, port, conn) != 0)
	{
		return ret;
	}

	conn.writePayload(RequestLoadLevelDb(path, create));
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
  Usage: load_db [Options...]

  Options:
    --help | -h
      Displays this help message

    --path=PATH | -pPATH
      Loads the Level database at PATH

    [--create=CREATE | -cCREATE = false]
      Should the database be created if it doens't
      exist? Default: false.
      Accepts: true, false`);
	printCommonHelp();
}