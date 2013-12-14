module server.server;

import types;
import sig;
import query;

import net.payload;
import net.common;

import server.connection_handler;
import server.context;

import image_db.base_db : BaseDb, IdGen;

import magick_wand.wand;

import std.stdio;
import std.variant;
import std.concurrency;
import std.algorithm;
import std.socket;
import core.thread : Thread;
import std.getopt : getopt;
import std.range : array;
import core.sync.mutex : Mutex;

// Version 0.1.0
enum VersionMajor = 0;
enum VersionMinor = 1;
enum VersionPatch = 0;
enum ServerVersion = ResponseVersion(VersionMajor, VersionMajor, VersionPatch);

private {
  // Is the server running? (So connections know when to shut down)
  __gshared bool _isServerRunning;
  __gshared Mutex runningMutex;

  shared static this()
  {
    _isServerRunning = true;
    runningMutex = new Mutex();
  }
}

bool isServerRunning()
{
  synchronized(runningMutex)
  {
    return _isServerRunning;
  }
}

void shutdownServer()
{
  synchronized(runningMutex)
  {
    _isServerRunning = false;
  }
}

int main(string[] args)
{
  ushort port = DefaultPort;
  string address = DefaultHost;
  bool   help = false;

  try
  {
    getopt(args, "help|h", &help, "bind|b", &address, "port|p", &port);
  }
  catch(Exception e)
  {
    writeln(e.msg);
    printHelp();
    return 1;
  }

  if(help)
  {
    printHelp();
    return 0;
  }

  writefln("Booting DIQS Server %s", ServerVersion.versionString());
  writefln("Starting server on %s:%d", address, port);

  // The main server context shared by all threads
  Context server_context = new Context();

  auto listener = new TcpSocket(AddressFamily.INET);
  listener.blocking = true;
  listener.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
  listener.bind(new InternetAddress(address, port));
  listener.listen(0);

  // On exit, close the listener connection
  scope(exit)
  {
    listener.shutdown(SocketShutdown.BOTH);
    listener.close();
  }

  SocketSet listener_set = new SocketSet();

  // An array of connections to remote clients
  Socket[] client_connections;

  while(true)
  {
    // Check that the server is still running
    if(!server_context.server_running)
    {
      writeln("Server was shutting down; notifying clients of imminent doom...");
      // Iterate through the clients and send them a shutdown signal
      foreach(client; client_connections)
      {
        client.writePayload(ResponseServerShutdown());
        client.shutdown(SocketShutdown.BOTH);
        client.close();
      }

      // Done, kill the server
      return 0;
    }

    listener_set.reset();

    listener_set.add(listener);
    foreach(conn; client_connections)
    {
      if(conn.isAlive())
        listener_set.add(conn);
    }

    auto select_ret = Socket.select(listener_set, null, null);

    if(select_ret < 1)
    {
      writeln("Socket error: ", select_ret);
      return -1;
    }

    if(listener_set.isSet(listener))
    {
      // A new connection was made; accept it and add it to the list
      // of client connections
      auto client = listener.accept();
      client.blocking = true;

      client_connections ~= client;

      writefln("Client connected from: '%s'", client.getHostname());
    }

    // Loop through the rest of the connections, responding to requests
    // on connections with data ready
    foreach(i, client; client_connections)
    {
      if(listener_set.isSet(client))
      {
        // Check if the client closed their connection
        try
        {
          handleClientRequest(client, server_context);
        }
        catch(ConnectionClosedException)
        {
          writefln("Client '%s' disconnected",
            client.getHostname());

          // Remove the client from the list of connections
          client_connections = client_connections.remove(i);
          continue;
        }

      }
    }

  }
  return 0;
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

string getHostname(Socket socket)
{
  return socket.remoteAddress().toHostNameString();
}