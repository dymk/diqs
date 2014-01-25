module client.commands.add_image;

import client.commands.common;
import net.common;
import types;

import std.getopt;

int main(string[] args)
{
	user_id_t db_id, image_id;
	bool help = false,
		got_db_id = false,
		got_image_id = false;
	string path;

	try
	{
		getopt(args,
			"db_id|d", (user_id_t _id) {
				got_db_id = true;
				db_id = _id;
			},
			"image_id|i", (user_id_t _id) {
				got_image_id = true;
				image_id = _id;
			},
			"path|p", (string _path) {
				got_path = true;
				path = _path;
			}
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

	if(!(got_db_id && got_path))
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

	conn.writePayload(
		RequestAddImageFromPath(db_id, got_image_id, image_id, path));

	conn.readPayload().tryVisit!(
		commonHandleResponseFailure,
		(ResponseImageAdded resp)
		{
			writeln("s::%d", resp.image_id);
		}
	);

	return 0;
}

void printHelp()
{
	writeln(`
  Usage: add_image [Options...]

  Options:
    --help | -h
      Displays this help message

    --db_id=DBID | -dDBID
      The database to insert the image in

    --image_id=IMGID | -iIMGID
      Optional parameter to specify what ID to give the image

    --path=PATH | -pPATH
      The path to the image to add to the database`);
	printCommonHelp();
}
