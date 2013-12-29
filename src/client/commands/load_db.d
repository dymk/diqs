module client.commands.load_db;

import client.commands.common;
import net.common;
import types;

import std.getopt;

int main(string[] args)
{
	string path;
	bool create = false;

	try
	{
		getopt(args,
			"path|p", &path,
			"create|c", &create);
	}
	catch(Exception e)
	{
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

	conn.writePayload(RequestLoadLevelDb(path, create));
	conn.readPayload().tryVisit!(
		(ResponseDbInfo resp)
		{
			printDbInfo(resp.db);
		}
	);

	return 0;
}
