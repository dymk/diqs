module client;

import types;

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
import std.string : chomp;
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

	void addImage(string image_path, user_id_t db_id, user_id_t image_id, bool gen_image_id) {
		RequestAddImageFromPath req;
		req.image_path = image_path;
		req.db_id = db_id;

		if(gen_image_id) {
			req.generate_id = true;
			req.image_id = image_id;
		} else {
			req.generate_id = false;
		}

		conn.writePayload(req);
		Payload resp = conn.readPayload();

		resp.tryVisit!(
			(ResponseImageAdded r) {
				writefln("Success | ID: %5d (DBID: %d)", r.image_id, r.db_id);
			},
			(ResponseFailure r) {
				writefln("Failure | %d", r.code);
			}
		)();
	}

	void genericLoadCreateFileDb(Req)(string db_path)
	if(is(Req == RequestCreateFileDb) || is(Req == RequestLoadFileDb))
	{
		Req req;
		req.db_path = db_path;

		conn.writePayload(req);
		conn.readPayload().tryVisit!(
			(ResponseDbInfo resp) {
				writeln("Loaded database: ");
				printDbInfo(resp.db);
			},
			(ResponseFailure resp) {
				writefln("Failure | %d", resp.code);
			}
		)();
	}

	while(true) {
		write("Select action (help): ");
		auto cmd_string = readln();
		if(cmd_string) {
			cmd_string = cmd_string.chomp();
		} else {
			cmd_string = "";
		}
		auto cmd_parts = cmd_string.split(" ");

		string command;
		if(cmd_parts.length == 0)
			command = "";
		else
			command = cmd_parts[0];

		if(command == "help" || command == "") {
			printCommands();
		}

		else if(command == "lsDbs") {
			listRemoteDbs();
		}

		else if(command == "createFileDb") {
			if(cmd_parts.length != 2) {
				writeln("createFileDb requires 1 argument");
				continue;
			}

			string db_path = cmd_parts[1];
			genericLoadCreateFileDb!RequestCreateFileDb(db_path);
		}

		else if(command == "loadFileDb") {
			if(cmd_parts.length != 2) {
				writeln("loadFileDb requires 1 argument");
				continue;
			}

			string db_path = cmd_parts[1];
			genericLoadCreateFileDb!RequestLoadFileDb(db_path);
		}

		else if(command == "addImage") {
			if(cmd_parts.length < 3 || cmd_parts.length > 4) {
				writeln("addImage requires 2 or 3 arguments");
				continue;
			}

			string image_path;
			user_id_t db_id;

			image_path = cmd_parts[1];
			formattedRead(cmd_parts[2], "%d", &db_id);

			if(cmd_parts.length == 4) {
				user_id_t image_id;
				formattedRead(cmd_parts[3], "%d", &image_path);

				addImage(image_path, db_id, image_id, false);
			} else {
				addImage(image_path, db_id, 0, true);
			}
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
    not specified, then a DB-unique ID is generated for the image.
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
