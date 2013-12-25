module client.help;

import client.client;

import net.common;
import std.stdio;

void printCommands() {
  writeln(`
  help
    Print this help

  lsDbs
    List the databases available on the server

  loadLevelDb PATH [CREATE_IF_NOT_EXIST]
    Loads a file database on the server at PATH. Fails if the database
    does not exist. If CREATE_IF_NOT_EXIST is 1, then the database is
    created if it doesn't exist.

  createLevelDb PATH
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

  flushDb DBID
    Flushes a database to whatever medium it's persisted on

  addImageBatch PATH DBID [FLUSH_PER=500]
    Adds a set of images to the database, where PATH is the path
    to a folder of images. The database is flushed (if it supports that)
    every FLUSH_PER images added (by default, the DB is flushed every 500
    images added).

  queryImage PATH DBID [NUM_RESULTS = 10]
    Perform a similarity query, listing the top NUM_RESULTS matches.

  shutdown
    Shuts down the server and closes all connections
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
