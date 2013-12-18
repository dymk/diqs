module server.context;

import std.stdio;
import std.variant;
import std.path;
import std.exception;

import image_db.all;

import net.db_info;


alias DbType = Algebraic!(
  PersistedDb,
  MemDb);

class Context
{
  static class ContextException : Exception
  {
    this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
  };

  final static class DbNotLoadedException : ContextException
  {
    this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
  };

  this()
  {
    db_id_gen = new shared IdGen!user_id_t();
  }

  DbInfo[] listDbInfo()
  {
    DbInfo[] list;
    list.reserve(databases.length);

    foreach(id, db; databases) {
      list ~= db.visit!(
        (PersistedDb fdb) { return DbInfo(id, fdb); },
        (MemDb  mdb) { return DbInfo(id, mdb); }
      )();
    }

    return list;
  }

  bool persistedDbIsLoaded(string path) {
    foreach(db; databases.byValue)
    {

      bool found = db.visit!(
        (PersistedDb fdb) { return fdb.path() == path; },
        (MemDb       mdb) { return false; }
      )();

      if(found)
        return true;
    }

    return false;
  }

  BaseDb getDbEx(user_id_t db_id)
  {
    DbType db = *enforceEx!DbNotLoadedException(db_id in databases, "Database isn't loaded");

    return db.visit!(
      (PersistedDb fdb) { return cast(BaseDb)fdb; },
      (MemDb       mdb) { return cast(BaseDb)mdb; }
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

  void close()
  {
    foreach(id, db; databases)
    {
      db.tryVisit!(
        (PersistedDb db)
        {
          writefln("Closing database at %s", db.path());
          db.close();
        }
      )();
    }
  }

private:
  DbType[user_id_t] databases;
  shared IdGen!user_id_t db_id_gen;
}
