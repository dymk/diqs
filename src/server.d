module server;

import types;

import net.payload;
import net.common;

import image_db.file_db : FileDb;
import image_db.base_db : IdGen;

import std.getopt : getopt;
import std.stdio : writeln, writefln, stderr;
import std.variant : Algebraic, tryVisit, visit;

import vibe.core.net : listenTCP;
import vibe.core.core : runEventLoop, lowerPrivileges;
import vibe.core.log;

enum VersionMajor = 0;
enum VersionMinor = 0;
enum VersionPatch = 1;

alias DbType = Algebraic!(
	FileDb,
	MemDb);

int main(string[] args)
{
	ushort port = DefaultPort;
	string address = DefaultHost;
	bool   help = false;

	try {
		getopt(args, "help|h", &help, "bind|b", &address, "port|p", &port);
	} catch(Exception e) {
		logCritical(e.msg);
		printHelp();
		return 1;
	}

	if(help) {
		printHelp();
		return 0;
	}

	setLogLevel(LogLevel.debugV);

	logInfo("Starting server on %s:%d", address, port);

	auto id_gen =  new IdGen!user_id_t;
	DbType[user_id_t] databases;

	bool fileDbIsLoaded(string path) {
		foreach(db; databases.byValue) {

			bool found = db.visit!(
				(FileDb fdb) {
					return fdb.path() == path;
				},
				(MemDb mdb) {
					return false;
				}
			)();

			if(found)
				return true;
		}

		return false;
	}

	void handleConnection(TCPConnection conn) {

		logInfo("Made a connection with %s", conn.peerAddress);

		void handleRequestPing(RequestPing req) {
			logTrace("Client requested Ping");
			conn.writePayload(ResponsePong());
		}

		void handleRequestVersion(RequestVersion r) {
			logTrace("Client requested Version");
			conn.writePayload(ResponseVersion(VersionMajor, VersionMinor, VersionPatch));
		}

		void handleRequestListDatabases(RequestListDatabases req) {
			DbInfo[] list;
			foreach(id, db; databases) {
				list ~= db.visit!(
					(FileDb fdb) {
						return DbInfo(id, fdb);
					},
					(MemDb mdb) {
						return DbInfo(id, mdb);
					}
				)();
			}

			conn.writePayload(ResponseListDatabases(list));
		}


		void handleoOpeningFileDatabase(R)(R req)
		if(is(R == RequestCreateFileDb) || is(R == RequestLoadFileDb))
		{
			logInfo("Got create/load database request: '%s'", req.db_path);

			if(fileDbIsLoaded(req.db_path)) {
				conn.writePayload(ResponseFailure(2));
				return;
			}

			static if(is(R == RequestCreateFileDb)) {
				FileDb db = FileDb.createFromFile(req.db_path);
			}
			else static if(is(R == RequestLoadFileDb)) {
				FileDb db = FileDb.loadFromFile(req.db_path, req.create_if_not_exist);
			}
			else {
				static assert(false);
			}

			auto db_id = id_gen.next();
			databases[db_id] = db;

			conn.writePayload(ResponseDbInfo(db_id, db));
		}

		void handleAddImageFromPath(RequestAddImageFromPath req) {

			DbType* db = req.db_id in databases;
			if(db is null) {
				conn.writePayload(ResponseFailure(2));
				return;
			}

			logTrace("Got add image from path request: %s: %s", req.db_id, req.image_path);

			// TODO: Finish up this logic.
			assert(false);
		}

		while(conn.connected) {
			Payload payload = conn.readPayload();

			payload.tryVisit!(
				handleRequestPing,
				handleRequestVersion,
				handleRequestListDatabases,
				handleoOpeningFileDatabase!RequestLoadFileDb,
				handleoOpeningFileDatabase!RequestCreateFileDb,
				handleAddImageFromPath);
		}
	}

	listenTCP(port, (conn) { handleConnection(conn); }, address);

	logDiagnostic("Running event loop...");
	int status;

	try {
		status = runEventLoop();
	} catch( Throwable th ){
		logError("Unhandled exception in event loop: %s", th.toString());
		return 1;
	}

	logDiagnostic("Event loop exited with status %d.", status);
	return status;
}

void printHelp() {
	writeln(
`
  Usage: server [Options...]

  Options:
    --help | -h
      Displays this help message

    --port=NUM | -pNUM
      Set the port that DIQS server listens on
      Default Value: 9548

    --bind=ADDR | -bADDR
      Set the address ADDR to bind the network listener to
      Default value: 127.0.0.1
`
	);
}
