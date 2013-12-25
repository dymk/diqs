module client.client;

import client.util;
import client.help;
import client.handlers;

import types;
import magick_wand.wand;
import sig;
import net.payload;
import net.common;
import net.db_info;

import std.file;
import std.stdio;
import std.getopt : getopt;
import std.variant : tryVisit;
import std.array : split;
import std.format : formattedRead;
import std.string;
import std.datetime : dur;
import std.socket;
import std.conv;
import std.algorithm;
import std.traits;
import std.typetuple;
import std.range;

private
{
  enum command_map = [
    "lsDbs": "doLsDbs",
    "loadDb": "doLoadLevelDb",
    "createDb": "doCreateDb",
    "queryImage": "doQueryImage"
  ];
  enum command_keys = command_map.keys;
}

// Props to CyberShadow
// http://dump.thecybershadow.net/c0f75fa4efb10b7fd9d07a1c74fea3fd/arr2tuple.d
template TupleOfArray(alias Arr)
{
  mixin(`alias TypeTuple!(` ~ Arr.length.iota.map!(i => "Arr[%d]".format(i)).join(",") ~ `) TupleOfArray;`);
}

int main(string[] args)
{
  ushort port = DefaultPort;
  string host = DefaultHost;
  bool   help = false;

  enum Delimer = " ";

  try
  {
    getopt(args, "help|h", &help, "host|h", &host, "port|p", &port);
  }
  catch(Exception e)
  {
    writeln(e.msg);
    printUsage();
    return 1;
  }

  if(help)
  {
    printUsage();
    return 0;
  }

  writefln("Connecting to %s:%d", host, port);

  Socket conn;
  try
  {
    conn = new TcpSocket(AddressFamily.INET);
    conn.blocking = true;
    conn.connect(new InternetAddress(host, port));
  }
  catch(SocketOSException e)
  {
    writefln("Wasn't able to connect to the server (%s)", e.msg);
    return 1;
  }

  scope(exit)
  {
    conn.shutdown(SocketShutdown.BOTH);
    conn.close();
  }

  conn.writePayload(RequestVersion());
  conn.readPayload().tryVisit!(
    (ResponseVersion r)
    {
      writefln("Connected to DIQS Server %s", r.versionString());
    }
  )();

  while(true)
  {
    write("> ");
    auto str_args = readln().strip.chomp.splitter(Delimer);

    if(str_args.empty)
      return 0;

    auto str_cmd  = str_args.front;
    str_args.popFront();

    dispatch(str_cmd, str_args, conn);
  }

  return 0;
}

void dispatch(Range)(string str_cmd, Range str_args, Socket conn)
if(isInputRange!Range)
{
  Lcommandswitch:
  switch(str_cmd.toLower)
  {

  foreach(cmd_user_str; TupleOfArray!command_keys)
  {
    enum cmd_func_str = command_map[cmd_user_str];
    case cmd_user_str.toLower:
      // e.g., `alias command = foo;`
      mixin("alias command = " ~ cmd_func_str ~ ";");
      alias ParamTypes    = ParameterTypeTuple!command;
      alias DefaultParams = ParameterDefaultValueTuple!command;

      ParamTypes args;

      foreach(i, ref arg; args)
      {
        static if(is(typeof(arg) == Socket))
        {
          arg = conn;
        }
        else
        if(str_args.empty)
        {
          static if(is(DefaultParams[i] == void))
          {
            writeln("Error, not enough arguments for command");
            break Lcommandswitch;
          }
          else
          {
            arg = DefaultParams[i];
          }
        }
        else
        {
          try
          {
            arg = str_args.front.to!(typeof(arg));
          }
          catch(ConvException e)
          {
            writefln(
              "Error parsing argument; expected type %s, which %s does not conform to: \n%s",
              typeid(arg), to!string(str_args.front), e.msg);
            break Lcommandswitch;
          }

          str_args.popFront;
        }
      }

      command(args);
      break Lcommandswitch;
  }

  default:
    writeln("Unknown or unsupported command");
  }

}
