module server;

import types;
import sig;

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


		void handleOpeningFileDatabase(R)(R req)
		{
			logInfo("Got create/load database request: '%s'", req.db_path);

			if(fileDbIsLoaded(req.db_path)) {
				conn.writePayload(ResponseFailure(ResponseFailure.Code.DbAlreadyLoaded));
				return;
			}

			static if(is(R == RequestCreateFileDb))
			{
				FileDb db = FileDb.createFromFile(req.db_path);
			}
			else static if(is(R == RequestLoadFileDb))
			{
				FileDb db = FileDb.loadFromFile(req.db_path, req.create_if_not_exist);
			}
			else
				static assert(false);

			auto db_id = id_gen.next();
			databases[db_id] = db;

			conn.writePayload(ResponseDbInfo(db_id, db));
		}

		void handleAddImageFromPath(RequestAddImageFromPath req) {
			logTrace("Got add image from path request: %s: %s (gen id? %s, id: %d)", req.db_id, req.image_path, req.generate_id, req.image_id);

			DbType* db = req.db_id in databases;
			if(db is null) {
				conn.writePayload(ResponseFailure(ResponseFailure.Code.DbNotFound));
				return;
			}

			void addImage(BaseDb bdb) {
				ImageSigDcRes image_data;
				try {
				 image_data = ImageSigDcRes.fromFile(req.image_path);
				}

				// Todo: Clean up exception catching code. There has to be a better way of
				// mapping exceptions to a response code, and returning from the function
				// early.
				catch(sig.CantOpenFileException e) {
					conn.writePayload(ResponseFailure(ResponseFailure.Code.CantOpenFile));
					return;
				}
				catch(sig.InvalidImageException e) {
					conn.writePayload(ResponseFailure(ResponseFailure.Code.InvalidImage));
					return;
				}
				catch(sig.CantResizeImageException e) {
					conn.writePayload(ResponseFailure(ResponseFailure.Code.CantResizeImage));
					return;
				}
				catch(sig.CantExportPixelsException e) {
					conn.writePayload(ResponseFailure(ResponseFailure.Code.CantExportPixels));
					return;
				}

				user_id_t image_id;
				if(req.generate_id) {
					image_id = bdb.nextId();
				} else {
					image_id = req.image_id;
				}

				try {
					bdb.addImage(image_data, image_id);
				}
				catch(BaseDb.AlreadyHaveIdException) {
					conn.writePayload(ResponseFailure(ResponseFailure.Code.AlreadyHaveId));
					return;
				}

				conn.writePayload(ResponseImageAdded(req.db_id, image_id));
			}

			(*db).visit!(
				(FileDb fdb) { addImage(fdb); },
				(MemDb mdb) { addImage(mdb); }
			)();
		}

		while(conn.connected) {
			Payload payload = conn.readPayload();

			try {
				payload.tryVisit!(
					handleRequestPing,
					handleRequestVersion,
					handleRequestListDatabases,
					handleOpeningFileDatabase!RequestLoadFileDb,
					handleOpeningFileDatabase!RequestCreateFileDb,
					handleAddImageFromPath);
			}
			catch(Exception e) {
				logError("Caught exception: %s (msg: %s)", e, e.msg);
				conn.writePayload(ResponseFailure(ResponseFailure.Code.UnknownException));
			}
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
