module client.util;

import net.db_info;

import std.stdio;
import std.socket;

void printDbInfo(DbInfo db_info)
{
  writef("DBID: %d | ", db_info.id);

  final switch(db_info.type) with (DbInfo.Type)
  {
    case Mem:   write("MemDb  "); break;
    case Level: write("LevelDb"); break;
  }

  writef(" | Images: %d", db_info.num_images);

  if(db_info.queryable) write(" | Queryable");
  if(db_info.persistable) write(" | Persistable");
  if(db_info.image_removable) write(" | ImageRemovable");

  if(db_info.persistable)
  {
    writef(" | Path: %s | Dirty?: %s", db_info.path, db_info.dirty);
  }

  writeln();
}

Socket connectToServer(string host, ushort port)
{
  Socket conn = new TcpSocket(AddressFamily.INET);
  conn.blocking = true;
  conn.connect(new InternetAddress(host, port));
  return conn;
}
