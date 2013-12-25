module client.handlers;

import client.util;

import types;
import net.payload;
import std.socket;
import std.stdio;
import std.string;
import std.variant;

static immutable handleResponseFailure = (ResponseFailure r)
{
  writefln("Failure | %2d | %s", r.code, r.code);
};

void doLsDbs(Socket conn)
{
  conn.writePayload(RequestListDatabases());

  DbInfo[] databases = conn.readPayload().get!ResponseListDatabases().databases;

  writefln("Databases: (%d) ", databases.length);
  foreach(db; databases) {
    db.printDbInfo();
  }
  writeln();
}

void doLoadLevelDb(Socket conn, string path, bool create = false)
{
	conn.writePayload(RequestLoadLevelDb(path, create));
	conn.readPayload.tryVisit!(
		handleResponseFailure,
		(ResponseDbInfo resp)
		{
			resp.db.printDbInfo();
		}
	)();
}

void doCreateDb(Socket conn, string type, string path = "")
{
	type = type.toLower;

	Payload req;
	if(type == "mem" || type == "memory")
	{
		req = RequestCreateMemDb();
	}
	else
	if(type == "level")
	{
		if(path == "")
		{
			writeln("LevelDb needs a path");
			return;
		}

		req = RequestCreateLevelDb(path);
	}
	else
	{
		writeln("Unknown db type: ", type);
		return;
	}

	conn.writePayload(req);
	conn.readPayload.tryVisit!(
		handleResponseFailure,
		(ResponseDbInfo resp)
		{
			resp.db.printDbInfo();
		}
	);
}

void doQueryImage(Socket conn, user_id_t db_id, string image_path, uint num_results = 10)
{
	conn.writePayload(RequestQueryFromPath(db_id, image_path, num_results));
	conn.readPayload().tryVisit!(
	  handleResponseFailure,
	  (ResponseQueryResults resp) {
	    writefln("Query took %d milliseconds to perform", resp.duration);
	    foreach(result; resp.results)
	    {
	      writefln("ID: %8d | Sim: %2.2f",
	        result.user_id, result.similarity);
	    }
	  }
	)();
}
