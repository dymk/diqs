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

static immutable handleResponseSuccess = (ResponseSuccess req)
{
	writeln("Success");
};

void doGenericRequest(ReqType, A...)(Socket conn, A args)
{
	conn.writePayload(ReqType(args));
	conn.readPayload().tryVisit!(
		handleResponseFailure,
		handleResponseSuccess
	);
}

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

void doCloseDb(Socket conn, user_id_t db_id)
{
	doGenericRequest!RequestCloseDb(conn, db_id);
}

void doAddImage(Socket conn, user_id_t db_id, string path, user_id_t image_id = -1)
{
	bool use_image_id = image_id != -1;
	conn.writePayload(RequestAddImageFromPath(
		db_id,
		use_image_id,
		image_id,
		path));

	conn.readPayload().tryVisit!(
		handleResponseFailure,
		(ResponseImageAdded r) {
			writefln("Success | ID: %5d", r.image_id);
		}
	);
}

void doAddImageBatch(Socket conn, user_id_t db_id, string path, uint flush_per_added = 500)
{
	conn.writePayload(RequestAddImageBatch(db_id, path, flush_per_added));
	bool keep_reading = true;
	while(keep_reading)
	{
		Payload resp = conn.readPayload();
		resp.tryVisit!(
			(ResponseImageAddedBatch r)
			{
				writefln("s::%s::%d::%d", r.image_path, r.db_id, r.image_id);
			},
			(ResponseFailureBatch r)
			{
				writefln("f::%s::%d", r.image_path, r.code);
			},
			(ResponseSuccessBatch r)
			{
				writefln("Done, %d images added; %d failures", r.num_images_added, r.num_failures);
				keep_reading = false;
			},
			(ResponseFailure r)
			{
				writefln("Fatal error during batch add: %d (%s)", r.code, r.code);
				keep_reading = false;
			}
		)();
	}
}

void doRemoveImage(Socket conn, user_id_t db_id, user_id_t image_id)
{
	doGenericRequest!RequestRemoveImage(conn, db_id, image_id);
}

void doMakeQueryable(Socket conn, user_id_t db_id)
{
	doGenericRequest!RequestMakeQueryable(conn, db_id);
}

void doDestroyQueryable(Socket conn, user_id_t db_id)
{
	doGenericRequest!RequestDestroyQueryable(conn, db_id);
}

void doShutdown(Socket conn)
{
	conn.writePayload(RequestServerShutdown());
	conn.readPayload().tryVisit!(
		handleResponseFailure,
		(ResponseServerShutdown resp) {
			writeln("Success, server shut down");
		}
	)();
}
