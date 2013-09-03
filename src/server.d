module server;

import types;

import net.payload;
import net.common;

import image_db.file_db : FileDb;

import std.getopt : getopt;
import std.stdio : writeln, writefln, stderr;
import std.variant : tryVisit;

import vibe.core.net : listenTCP;
import vibe.stream.operations : readLine;
import vibe.core.core : runEventLoop, lowerPrivileges;
import vibe.core.log;

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

	FileDb filedb;

	listenTCP(port, (conn) {
		logInfo("Made a connection with %s", conn.peerAddress);

		while(conn.connected) {
			Payload payload = conn.readPayload();

			payload.tryVisit!(
				(RequestPing req) {
					conn.writePayload(ResponsePong());
					logInfo("Client requested Ping");
				},

				(RequestLoadDbFile req) {
					logInfo("Got load database request: '%s' (create if not exist: %s)", req.path, req.create_if_not_exist);

					// TODO: Load the database file here

					if(req.create_if_not_exist) {
						conn.writePayload(ResponseSuccess());
					} else {
						conn.writePayload(ResponseFailure(1234));
					}
				},
				() {
					logError("A payload who's handler hasn't been implemented has been recieved: %s", payload);
				}
			)();
		}
	}, address);

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
