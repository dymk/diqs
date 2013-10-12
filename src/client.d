module client;

import types;
import magick_wand.wand;
import sig : ImageSig;

import net.payload;
import net.common;
import net.db_info;

import vibe.core.net : connectTCP;
import vibe.core.core : sleep;
import vibe.core.log;

import std.stdio : write, writeln, writefln, readln;
import std.getopt : getopt;
import std.variant : tryVisit;
import std.array : split;
import std.format : formattedRead, format;
import std.string : chomp, strip;
import std.datetime : dur;

int main(string[] args)
{
	ushort port = DefaultPort;
	string host = DefaultHost;
	bool   help = false;

	try {
		getopt(args, "help|h", &help, "host|h", &host, "port|p", &port);
	} catch(Exception e) {
		logCritical(e.msg);
		printUsage();
		return 1;
	}

	if(help) {
		printUsage();
		return 0;
	}

	logInfo("Connecting to %s:%d", host, port);
	auto conn = connectTCP(host, port);

	conn.writePayload(RequestVersion());
	conn.readPayload().tryVisit!((ResponseVersion r) {
			writefln("Connected to DIQS Server %d.%d.%d", r.major, r.minor, r.patch);
		}
	)();

	static printDbInfo(DbInfo db_info) {
		final switch(db_info.type) with(DbInfo.Type) {
			case Mem:
				writefln("MemDb:  | ID: %5d | Images: %5d", db_info.id, db_info.num_images);
				break;
			case File:
				writefln("FileDb: | ID: %5d | Images: %5d | Dirty? %s | Path: %s", db_info.id, db_info.num_images, db_info.dirty, db_info.path);
				break;
		}
	}

	immutable handleFailure = (ResponseFailure r) {
		writefln("Failure | %s", r.code);
	};

	void listRemoteDbs() {
		conn.writePayload(RequestListDatabases());

		DbInfo[] databases = conn.readPayload().tryVisit!(
			(ResponseListDatabases resp) {
				return resp.databases;
			}
		)();

		writefln("Databases: (%d) ", databases.length);
		foreach(db; databases) {
			printDbInfo(db);
		}
		writeln();
	}

	// An attempt to DRY up the addImage and addImageRemote functions
	void setupAddImageRequest(P)(ref P req, user_id_t db_id, user_id_t image_id, bool use_image_id)
	{
		req.db_id = db_id;
		req.use_image_id = use_image_id;
		req.image_id = image_id;
	}

	void addImage(string image_path, user_id_t db_id, user_id_t image_id, bool use_image_id) {
		RequestAddImageFromPath req;
		setupAddImageRequest(req, db_id, image_id, use_image_id);
		req.image_path = image_path;

		conn.writePayload(req);
	}

	void addImageRemote(
		   string  image_path,
		user_id_t  db_id,
		     bool  local_resize,
		user_id_t  image_id,
		     bool  use_image_id)
	{
		RequestAddImageFromPixels req;
		setupAddImageRequest(req, db_id, image_id, use_image_id);

		try {
			auto wand = MagickWand.fromFile(image_path);
			scope(exit) { MagickWand.disposeWand(wand); }

			req.original_res = ImageRes(
				cast(ushort) wand.imageWidth(),
				cast(ushort) wand.imageHeight()
			);

			if(local_resize) {
				ImageSig.resizeWand(wand);
			}

			req.pixels_res = ImageRes(
				cast(ushort) wand.imageWidth(),
				cast(ushort) wand.imageHeight()
			);

			req.pixels = wand.exportImagePixelsFlatEx!RGB();
		}
		catch(WandException e)
		{
			logError("Couldn't process image file %s: %s", image_path, e);
			return;
		}

		scope(exit) { GC.free(req.pixels.ptr); }

		conn.writePayload(req);
	}

	void genericLoadCreateFileDb(Req)(string db_path)
	if(is(Req == RequestCreateFileDb) || is(Req == RequestLoadFileDb))
	{
		Req req;
		req.db_path = db_path;

		conn.writePayload(req);
		conn.readPayload().tryVisit!(
			handleFailure,
			(ResponseDbInfo r) {
				writeln("Loaded database: ");
				printDbInfo(r.db);
			}
		)();
	}

	void genericHandleImageAddResponse()
	{
		Payload resp = conn.readPayload();
		resp.tryVisit!(
			handleFailure,
			(ResponseImageAdded r) {
				writefln("Success | ID: %5d (DBID: %d)", r.image_id, r.db_id);
			}
		)();
	}

	while(true) {
		write("Select action (help): ");
		auto cmd_string = readln();
		if(cmd_string) {
			cmd_string = cmd_string.chomp().strip();
		} else {
			cmd_string = "";
		}

		scope scope_cmd_parts = cmd_string.split();
		string[] cmd_parts = scope_cmd_parts;

		string command;
		if(cmd_parts.length == 0)
			command = "";
		else {
			command = cmd_parts[0];
			cmd_parts = cmd_parts[1..$];
		}

		writeln("CMD parts: ", cmd_parts);

		if(command == "help" || command == "") {
			printCommands();
		}

		else if(command == "lsDbs") {
			listRemoteDbs();
		}

		else if(command == "createFileDb") {
			if(cmd_parts.length != 1) {
				writeln("createFileDb requires 1 argument");
				continue;
			}

			string db_path = cmd_parts[0];
			genericLoadCreateFileDb!RequestCreateFileDb(db_path);
		}

		else if(command == "loadFileDb") {
			if(cmd_parts.length != 1) {
				writeln("loadFileDb requires 1 argument");
				continue;
			}

			string db_path = cmd_parts[0];
			genericLoadCreateFileDb!RequestLoadFileDb(db_path);
		}

		else if(command == "addImage") {
			if(cmd_parts.length < 2 || cmd_parts.length > 3) {
				writefln("addImage requires 2 or 3 arguments");
				continue;
			}

			string image_path;
			user_id_t db_id;

			image_path = cmd_parts[0];
			formattedRead(cmd_parts[1], "%d", &db_id);

			bool use_image_id = (cmd_parts.length == 3);

			user_id_t image_id;
			if(!use_image_id) {
				formattedRead(cmd_parts[2], "%d", &image_id);
			}

			addImage(image_path, db_id, image_id, use_image_id);
			genericHandleImageAddResponse();
		}

		else if(command == "addImageRemote")
		{
			if(cmd_parts.length < 2 || cmd_parts.length > 4) {
				writefln("addImageRemote requires 2 to 4 arguments");
				continue;
			}

			string image_path;
			user_id_t db_id;

			image_path = cmd_parts[0];
			formattedRead(cmd_parts[1], "%d", &db_id);

			bool use_image_id = (cmd_parts.length == 4);

			bool local_resize;
			if(cmd_parts.length >= 3) {
				// If the LOCAL_RESIZE was 1, then resize on this machine.
				// Else, let the server take care of resizing.
				int local_resize_val;
				formattedRead(cmd_parts[2], "%d", &local_resize_val);

				local_resize = local_resize_val == 1;
			}

			user_id_t image_id;
			if(use_image_id) {
				formattedRead(cmd_parts[3], "%d", &image_id);
			}

			addImageRemote(image_path, db_id, local_resize, image_id, use_image_id);
			genericHandleImageAddResponse();
		}

		else if(command == "queryImage")
		{
			if(cmd_parts.length < 2 || cmd_parts.length > 3) {
				writeln("queryImage requires 2 or 3 arguments");
				continue;
			}

			string image_path = cmd_parts[0];
			user_id_t db_id;
			formattedRead(cmd_parts[1], "%d", &db_id);

			uint num_results = 10;
			if(cmd_parts.length == 3) {
				formattedRead(cmd_parts[2], "%d", &num_results);
			}

			conn.writePayload(RequestQueryFromPath(db_id, image_path, num_results));
			conn.readPayload().tryVisit!(
				handleFailure,
				(ResponseQueryResults resp) {
					foreach(result; resp.results)
					{
						writefln("ID: %8d | Sim: %2.2f | Res: %dx%d",
							result.user_id, result.similarity,
							result.res.width, result.res.height);
					}
				}
			)();
		}

		else {
			writefln("Unknown command '%s'", command);
		}
	}
}

void printCommands() {
	writeln(`
  help
    Print this help

  lsDbs
    List the databases available on the server

  loadFileDb PATH
    Loads a file database on the server at PATH. Fails if the database
    does not exist.

  createFileDb PATH
    Creates and loads new file database on the server at PATH.
    Fails if the database already exists.

  addImage PATH DBID [IMGID]
    Add image at path PATH to the database with id DBID. If IMGID is
    not specified, then a DB-unique ID is generated for the image. Assumes
    that PATH is accessible to the server.

  addImageRemote PATH DBID [LOCAL_RESIZE = 1 [IMGID]]
    Adds an image to the database, like addImage. However, this command is
    used when the server is on a remote machine without access to the file
    at PATH, and needs to be transmitted to the server over the network.
    If LOCAL_RESIZE is 1, then the image is resized on the client and sent
    to the server, else, the resizing is done on the server. It's recommended
    that LOCAL_RESIZE is set to 1 if images are being transmitted over a low
    bandwidth connection. Defaults to 1.

  queryImage PATH DBID [NUM_RESULTS = 10]
    Perform a similarity query, listing the top NUM_RESULTS matches.
`);
}

void printUsage() {
	writefln(
`
  Usage: server [Options...]

  Options:
    --help | -h
      Displays this help message

    --port=NUM | -pNUM
      Set the port of the DIQS server to connect to
      Default Value: %d

    --host=ADDR | -hADDR
      Set the host/address of the DIQS server to connect to
      Default Value: %s
`,
	DefaultPort, DefaultHost);
}
