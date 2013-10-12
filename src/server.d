module server;

import types;
import sig;
import query;

import net.payload;
import net.common;

import image_db.file_db : FileDb;
import image_db.base_db : BaseDb, IdGen;

import magick_wand.wand;

import std.getopt : getopt;
import std.stdio : writeln, writefln, stderr;
import std.variant : Algebraic, tryVisit, visit;
import std.range : array;

import vibe.core.net : listenTCP;
import vibe.core.core : runEventLoop, lowerPrivileges;
import vibe.inet.path : Path;
import vibe.core.log;

enum VersionMajor = 0;
enum VersionMinor = 0;
enum VersionPatch = 1;

class ServerException : Exception {
	this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
};
final class DatabaseNotFoundException : ServerException {
	this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
};

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
					return Path(fdb.path()) == Path(path);
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

	BaseDb enforceHasDb(user_id_t db_id)
	{
		DbType db = *enforceEx!DatabaseNotFoundException(db_id in databases, "Database isn't loaded");

		return db.visit!(
			(FileDb fdb) { return cast(BaseDb)fdb; },
			(MemDb mdb)  { return cast(BaseDb)mdb; }
		)();
	}

	void handleConnection(TCPConnection conn) {

		logInfo("Made a connection with %s", conn.peerAddress);

		void handleRequestPing(RequestPing req) {
			logDebug("Client requested Ping");
			conn.writePayload(ResponsePong());
		}

		void handleRequestVersion(RequestVersion r) {
			logDebug("Client requested Version");
			conn.writePayload!ResponseVersion(ResponseVersion(VersionMajor, VersionMinor, VersionPatch));
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
				logDiagnostic("Created database at path %s", req.db_path);
			}
			else static if(is(R == RequestLoadFileDb))
			{
				FileDb db = FileDb.loadFromFile(req.db_path, req.create_if_not_exist);
				logDiagnostic("Loaded database at path %s", req.db_path);
			}
			else
				static assert(false, "Request type must be LoadFileDb or CreateFileDb");


			auto db_id = id_gen.next();
			databases[db_id] = db;

			conn.writePayload(ResponseDbInfo(db_id, db));
		}

		// Generic add image data from request and image data
		void addImageData(Req)(ImageSigDcRes image_data, Req req)
		if(
			is(Req == RequestAddImageFromPath) ||
			is(Req == RequestAddImageFromPixels))
		{
			BaseDb bdb = enforceHasDb(req.db_id);

			user_id_t image_id;
			if(req.use_image_id) {
				image_id = req.image_id;
			} else {
				image_id = bdb.peekNextId();
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

		void handleAddImageFromPath(RequestAddImageFromPath req) {
			logDebug("Got add image from path request: %s (dbid: %d, use id? %s, id: %d)",
				req.image_path, req.db_id, req.use_image_id, req.image_id);

			// This is an ugly workaround to handle ImageMagick not liking
			// fibers. Perhaps yield this fiber after spawning the thread and
			// sending the path, and then having the spawned thread signal
			// for the fiber to resume? More research required.
			auto imageDataThreadId = spawn(&genImageDataFunc, thisTid);
			send(imageDataThreadId, req.image_path);
			ImageSigDcRes image_data = receiveOnly!ImageSigDcRes();

			logDebug("Processed image data (res %dx%d)",
				image_data.res.width, image_data.res.height);

			addImageData(image_data, req);
		}

		void handleAddImageFromPixels(RequestAddImageFromPixels req) {
			logDebug("Got add image from pixels request: %s (use id? %s, id: %d)",
				req.db_id, req.use_image_id, req.image_id);

			scope(exit) {
				GC.free(req.pixels.ptr);
			}

			auto wand = MagickWand.getWand();
			scope(exit) {
				MagickWand.disposeWand(wand);
			}

			wand.newImageEx(
				req.pixels_res.width,
				req.pixels_res.height);

			wand.importImagePixelsFlatEx(
				req.pixels_res.width,
				req.pixels_res.height,
				req.pixels);

			logDebug("Imported wand; image res: %dx%d",
				wand.imageWidth(), wand.imageHeight());

			ImageSigDcRes image_data = ImageSigDcRes.fromWand(wand);
			image_data.res = req.original_res;

			addImageData(image_data, req);
		}

		void handleQueryFromPath(RequestQueryFromPath req)
		{
			BaseDb db = enforceHasDb(req.db_id);

			QueryParams qp;

			scope(exit) {
				GC.free(cast(void*)req.image_path.ptr);
			}

			auto imageDataThreadId = spawn(&genImageDataFunc, thisTid);
			send(imageDataThreadId, req.image_path);
			ImageSigDcRes input = receiveOnly!ImageSigDcRes();

			qp.in_image = &input;
			qp.num_results = req.num_results;

			scope(exit) {
				GC.free(query_results.ptr);
				GC.free(resp_results.ptr);
			}
			auto query_results = db.query(qp);
			auto resp_results = query_results.map!(
				(result) {
					return ResponseQueryResults.QueryResult(
						result.image.user_id,
						result.similarity,
						result.image.res);
				}
 			)().array();

			conn.writePayload(ResponseQueryResults(resp_results));
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
					handleAddImageFromPath,
					handleAddImageFromPixels,
					handleQueryFromPath);
			}
			catch(DatabaseNotFoundException) {
				conn.writePayload(ResponseFailure(ResponseFailure.Code.DbNotFound));
			}

			catch(magick_wand.wand.NonExistantFileException e) {
				conn.writePayload(ResponseFailure(ResponseFailure.Code.NonExistantFile));
			}

			catch(magick_wand.wand.InvalidImageException e) {
				conn.writePayload(ResponseFailure(ResponseFailure.Code.InvalidImage));
			}

			catch(magick_wand.wand.CantResizeImageException e) {
				conn.writePayload(ResponseFailure(ResponseFailure.Code.CantResizeImage));
			}

			catch(magick_wand.wand.CantExportPixelsException e) {
				conn.writePayload(ResponseFailure(ResponseFailure.Code.CantExportPixels));
			}

			catch(FileDb.DbFileAlreadyExistsException e) {
				conn.writePayload(ResponseFailure(ResponseFailure.Code.DbFileAlreadyExists));
			}

			catch(FileDb.DbFileNotFoundException e) {
				conn.writePayload(ResponseFailure(ResponseFailure.Code.DbFileNotFound));
			}

			catch(Exception e) {
				logError("Caught exception: %s (msg: %s)", e, e.msg);
				conn.writePayload(ResponseFailure(ResponseFailure.Code.UnknownException));
			}
		}
	}

	int status;

	try
	{
		listenTCP(port, (conn) { handleConnection(conn); }, address);

		logDiagnostic("Running event loop...");

		status = runEventLoop();
		logDiagnostic("Event loop exited with status %d.", status);

	}
	catch(core.exception.InvalidMemoryOperationError e)
	{
		writeln(e);
		return -1;
	}

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

// A workaround for MagickWand. Processes MagickWand work in a separate
// thread, because MagickWand doesn't like fibers.
import std.concurrency;
void genImageDataFunc(Tid tid) {
	receive((string image_path) {
		send(tid, ImageSigDcRes.fromFile(image_path));
	});
}
