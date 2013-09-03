module client;

import net.payload;
import net.common;

import std.stdio : writeln, writefln;
import std.getopt : getopt;

import vibe.core.net : connectTCP;
import vibe.stream.operations : readLine;
import vibe.core.core : sleep;
import vibe.core.log;

import std.variant : tryVisit;

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
		printHelp();
		return 1;
	}

	if(help) {
		printHelp();
		return 0;
	}

	logInfo("Connecting to %s:%d", host, port);
	auto conn = connectTCP(host, port);

	alias respHandler = tryVisit!(
		(ResponseSuccess r) {
			logInfo("Responded with success!");
		},
		(ResponseFailure r) {
			logInfo("Responded with error! Code: %d", r.code);
		},
		(ResponsePong r) {
			logInfo("Server: PONG");
		},
		() {
			logError("Unexpected response from server");
		}
	);

	Payload resp;

	while(true) {
		sleep(dur!"msecs"(1));

		conn.writePayload(RequestPing());
		resp = conn.readPayload();
		respHandler(resp);
	}
}

void printHelp() {
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
