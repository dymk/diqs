module client.commands.close_db;

import client.commands.common;
import net.common;
import types;

import std.getopt;

int main(string[] args)
{
	user_id_t db_id = -1;
	bool help = false;

	try
	{
		getopt(args,
			"db_id|d", &db_id,
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

	if(db_id == -1)
	{
		stderr.writeln("need a db_id");
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

	conn.writePayload(RequestCloseDb(db_id));

	conn.readPayload().tryVisit!(
		commonHandleResponseFailure,
		(ResponseSuccess resp)
		{
			writeln("s");
		}
	);

	return 0;
}

void printHelp()
{
	writeln(`
  Usage: close_db [Options...]

  Options:
    --help | -h
      Displays this help message

    --db_id=DBID | -dDBID
      Close DBID on the server`);
	printCommonHelp();
}