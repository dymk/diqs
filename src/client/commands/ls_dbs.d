module client.commands.ls_dbs;

import client.commands.common;
import net.common;
import types;

import std.getopt;

int main(string[] args)
{
	bool help = false;

	try
	{
		getopt(args,
			"help|h", &help);
	}
	catch(Exception e)
	{
		printFailure(ErrorCode.InvalidOptions);
		return ErrorCode.InvalidOptions;
	}

	if(help)
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

	conn.writePayload(RequestListDatabases());

	DbInfo[] databases = conn.readPayload().get!ResponseListDatabases().databases;

	foreach(db; databases) {
		db.printDbInfo();
	}

	return 0;
}

void printHelp()
{
	writeln(`
  Usage: ls_dbs [Options...]

  Options:
    --help | -h
      Displays this help message`);
	printCommonHelp();
}