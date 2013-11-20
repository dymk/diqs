module server.context;

import std.variant;
import std.path;
import std.exception;

import image_db.mem_db;
import image_db.file_db;
import image_db.base_db;

import net.db_info;

class ContextException : Exception
{
  this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
};

final class DatabaseNotFoundException : ContextException
{
  this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
};

alias DbType = Algebraic!(
  FileDb,
  MemDb);

class Context
{
  this()
  {
    db_id_gen = new IdGen!user_id_t();
  }

  DbInfo[] listDbInfo()
  {
    DbInfo[] list;
    list.reserve(databases.length);

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

    return list;
  }

  bool fileDbIsLoaded(string path) {
    foreach(db; databases.byValue) {

      bool found = db.visit!(
        (FileDb fdb) {
          return buildPath(fdb.path()) == buildPath(path);
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

  BaseDb getDbEx(user_id_t db_id)
  {
    DbType db = *enforceEx!DatabaseNotFoundException(db_id in databases, "Database isn't loaded");

    return db.visit!(
      (FileDb fdb) { return cast(BaseDb)fdb; },
      (MemDb mdb)  { return cast(BaseDb)mdb; }
    )();
  }

  user_id_t addDb(DbType db)
  {
    auto id = db_id_gen.next();
    databases[id] = db;
    return id;
  }

  auto nextDbID()
  {
    return db_id_gen.next();
  }

  bool server_running = true;

private:
  DbType[user_id_t] databases;
  IdGen!user_id_t db_id_gen;
}