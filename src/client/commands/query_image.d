module client.commands.create_db;

import client.commands.common;
import net.common;
import types;

import std.getopt;

int main(string[] args)
{
	string path;
	user_id_t db_id = -1;
	uint num_results = 10;
	bool help = false;

	try
	{
		getopt(args,
			"path|p", &path,
			"db_id|d", &db_id,
			"num_results|n", &num_results,
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

	if(path == "" || db_id == -1)
	{
		stderr.writeln("need both a path and db_id");
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

	conn.writePayload(RequestQueryFromPath(db_id, path, num_results));

	conn.readPayload().tryVisit!(
		commonHandleResponseFailure,
		(ResponseQueryResults resp)
		{
			writefln("s::%d::%d", resp.results.length, resp.duration);
			foreach(result; resp.results)
			{
				writefln("sb::%d::%2.2f",
					result.user_id, result.similarity);
			}
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