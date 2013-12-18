module image_db.level_db;

import image_db.all;
import image_db.bucket_manager;
import sig;

import msgpack;
import deimos.leveldb.leveldb;

import std.stdio;
import std.string : toStringz;
import std.conv : to;
import std.algorithm;
import std.file;
import std.exception;
import std.path : buildPath;

// Read options for iterators and write for DB writes
private __gshared leveldb_readoptions_t ReadOptions;
private __gshared leveldb_writeoptions_t WriteOptions;
shared static this()
{
  ReadOptions = leveldb_readoptions_create();
  WriteOptions = leveldb_writeoptions_create();
}
shared static ~this()
{
  leveldb_readoptions_destroy(ReadOptions);
  ReadOptions = null;

  leveldb_writeoptions_destroy(WriteOptions);
  WriteOptions = null;
}

final class LevelDb : PersistedDb, ReservableDb
{
private:
  // The memdb that has queries delegated to it
  MemDb mem_db;

  // The backing leveldb implementation
  leveldb_t db;
  leveldb_options_t opts;

  // Location in the filesystem of the database
  string db_path;

  // msgpacked BucketSizes*
  immutable string bs_path;

  // Have to keep a reference to all iterators to close them
  // when the DB is closed
  LevelDbImageIterator[] iterators;

public:

  this(string db_path, bool create_if_missing = false)
  {
    this.mem_db = new MemDb();
    scope(failure) { mem_db.destroy(); }

    this.db_path = db_path;

    opts = enforce(leveldb_options_create(), "Failed to prepare DB open/create");
    leveldb_options_set_create_if_missing(opts, create_if_missing);

    char* errptr = null;
    scope(failure) if(errptr !is null) leveldb_free(errptr);

    this.db = leveldb_open(opts, db_path.toStringz(), &errptr);

    if(errptr && errptr.to!string.canFind("nonexistant"))
    {
      throw new PersistedDb.DbNonexistantException(errptr.to!string);
    }

    enforce(errptr is null, errptr.to!string);

    bs_path = buildPath(db_path, "BUCKET_SIZES");

    load();
  }

  ~this()
  {
    close();
    leveldb_options_destroy(opts);
    if(mem_db) mem_db.destroy();
    db.destroy();
  }

  user_id_t addImage(const(ImageIdSigDcRes*) img)
  {
    auto ret = mem_db.addImage(img);
    addImageToLevel(img);

    return ret;
  }

  /**
   * Inserts an image without a yet determind ID into the database
   * and returns its assigned ID. The database will determine what
   * ID to give the image.
   */
  user_id_t addImage(const(ImageSigDcRes*) img)
  {
    auto img_id = mem_db.addImage(img);
    auto id_img = ImageIdSigDcRes.fromSigDcRes(img_id, *img);
    addImageToLevel(&id_img);

    return img_id;
  }

  user_id_t addImage(user_id_t user_id, const(ImageSigDcRes*) img)
  {
    auto id_img = ImageIdSigDcRes.fromSigDcRes(user_id, *img);
    return addImage(&id_img);
  }

  bool getImage(user_id_t user_id, out ImageIdSigDcRes img) const
  {
    char* errptr = null;
    scope(exit) if(errptr) leveldb_free(errptr);

    size_t vallen;
    auto valptr = leveldb_get(
      cast(void*) db,
      ReadOptions,
      cast(char*) &user_id,
      user_id_t.sizeof,
      &vallen,
      &errptr);

    scope(exit)
    {
      if(valptr !is null) leveldb_free(valptr);
    }

    if (valptr is null)
    {
      return false;
    }

    enforce(vallen == ImageIdSigDcRes.sizeof, "Returned value in DB isn't the size of an image");
    img = *(cast(ImageIdSigDcRes*) valptr);
    return true;
  }

  void removeImage(user_id_t user_id, ImageIdSigDcRes* ret_img)
  {
    ImageIdSigDcRes persisted_ret;
    auto was_in_level = getImage(user_id, persisted_ret);

    enforce(was_in_level);

    version(assert)
    {
      // Ensure that the image in the memory database is the same as the one on the
      // disk
      ImageIdSigDc mem_ret;
      mem_db.removeImage(user_id, &mem_ret);
      assert(mem_ret.sig.sameAs(persisted_ret.sig));
      assert(mem_ret.dc == persisted_ret.dc);
    }

    char* errptr = null;
    scope(exit) if(errptr) leveldb_free(errptr);

    leveldb_delete(db, WriteOptions, cast(char*) &user_id, typeid(user_id).sizeof, &errptr);

    // Perhaps, this can be made a warning, although it is concerning that
    // the memdb was out of sync with the persisted db
    enforce(errptr is null, "LevelDb Error: " ~ errptr.to!string);

    if(ret_img != null)
    {
      *ret_img = persisted_ret;
    }
  }

  void removeImage(user_id_t user_id)
  {
    removeImage(user_id, null);
  }

  uint numImages() const
  {
    return mem_db.numImages();
  }

  user_id_t peekNextId() const
  {
    return mem_db.peekNextId();
  }

  QueryResult[] query(QueryParams params) const
  {
    return mem_db.query(params);
  }

  MemDb releaseMemDb()
  {
    auto ret = mem_db;
    mem_db = null;
    close();
    return ret;
  }

  bool released() const
  {
    return mem_db is null;
  }

  // TODO: Make this do something more useful.
  bool flush() { return true; }
  bool dirty() const { return false;}

  bool closed() const { return db is null; }

  void close()
  {

    if(!closed())
    {
      if(mem_db)
      {
        scope bucket_sizes = mem_db.bucketSizes();
        auto bs_packed = msgpack.pack(*bucket_sizes);
        std.file.write(bs_path, bs_packed);
      }

      foreach(LevelDbImageIterator iter; iterators)
      {
        iter.close();
      }

      leveldb_close(db);
      db = null;
    }
  }

  LevelDbImageIterator imageDataIterator()
  {
    auto iter = new LevelDbImageIterator(db);
    iterators ~= iter;
    return iter;
  }

  string path() const
  {
    return db_path;
  }

  // Reserves room for 'amt' images in the database
  void reserve(size_t amt)
  {
    if(mem_db)
    {
      mem_db.reserve(amt);
    }
  }

private:
  void load()
  {
    if(exists(bs_path))
    {
      ubyte[] bs_packed = cast(ubyte[]) std.file.read(bs_path);
      BucketSizes sizes;
      msgpack.unpack(bs_packed, sizes);

      mem_db.bucketSizeHint(&sizes);
    }

    foreach(ref img; this.imageDataIterator())
    {
      mem_db.addImage(&img);
    }
  }

  void addImageToLevel(const(ImageIdSigDcRes*) img)
  {
    char* errptr = null;
    scope(exit) if(errptr) leveldb_free(errptr);

    // TODO: add support for batch image insertions

    // Also, TODO: Perhaps it should write an ImageSigDcRes instead of including
    // the ID, but well, for now this makes iterating really easy
    leveldb_put(db, WriteOptions,
      cast(char*) &(img.user_id),
      user_id_t.sizeof,
      cast(char*) img,
      ImageIdSigDcRes.sizeof, &errptr);

    enforce(errptr is null, "LevelDb error: " ~ errptr.to!string);
  }

  // Iterator for image data within the leveldb
  final static class LevelDbImageIterator : ImageDataIterator
  {
    this(leveldb_t db)
    {
      _iter = enforce(leveldb_create_iterator(db, ReadOptions));
      leveldb_iter_seek_to_first(_iter);
    }

    ~this()
    {
      close();
    }

    user_id_t key() const
    {
      enforceIter();
      size_t keylen;
      auto key = leveldb_iter_key(_iter, &keylen);
      // scope(exit) if(key) leveldb_free(key);

      enforce(keylen == user_id_t.sizeof);

      return *(cast(user_id_t*) key);
    }

    ImageIdSigDcRes value() const
    {
      enforceIter();
      size_t vallen;
      auto val = leveldb_iter_value(_iter, &vallen);
      // scope(exit) if(val) leveldb_free(val);

      enforce(vallen == ImageIdSigDcRes.sizeof, "DB ret size was " ~ vallen.to!string ~ " should have been " ~ ImageIdSigDcRes.sizeof.to!string);

      return *(cast(ImageIdSigDcRes*) val);
    }

    ImageIdSigDcRes front() const { return value(); }
    bool empty()            const { enforceIter(); return leveldb_iter_valid(_iter) == 0 ? true : false; }
    void popFront()               { enforceIter(); return leveldb_iter_next(_iter); }

    void close()
    out
    {
      assert(_iter is null);
    }
    body
    {
      if(_iter !is null)
      {
        leveldb_iter_destroy(_iter);
        _iter = null;
      }
    }

  private:
    void enforceIter() const
    {
      enforce(_iter, "Iterator has been closed");
    }

    leveldb_iterator_t _iter;
  }
}

version(unittest)
{
  const __gshared const(string) temp_dir;
  shared static this()
  {
    temp_dir = buildPath(tempDir(), "leveldb_backed_tmp");

    try
    {
      mkdirRecurse(temp_dir);
    } catch (Exception e) {}
  }

  shared static ~this()
  {
    try
    {
      rmdirRecurse(temp_dir);
    } catch (Exception e) {}
  }

  string getTempPath(string base)
  {
    return buildPath(temp_dir, base);
  }

  // Returns a new, unique LevelDb
  static int ldb_num = 0;
  static immutable leveldb_options_t temp_destroy_opts;

  static this()
  {
    temp_destroy_opts = cast(immutable(void*)) enforce(leveldb_options_create());
  }

  LevelDb getTempLevelDb()
  {
    string tmp_path = getTempPath(ldb_num.to!string);

    char* errptr = null;
    leveldb_destroy_db(temp_destroy_opts, tmp_path.toStringz(), &errptr);

    enforce(errptr is null, errptr.to!string);

    try {
      rmdirRecurse(tmp_path);
    } catch(Exception e) {}

    scope(exit) { ldb_num++; }
    return new LevelDb(tmp_path, true);
  }
}

unittest
{
  bool thrown = false;
  try
  {
    new LevelDb("nonexistant");
  }
  catch(PersistedDb.DbNonexistantException e)
  {
    thrown = true;
  }
  catch(Exception e) { writeln("Wrong exception thrown: ", e.msg); }
  assert(thrown);
}

unittest
{
  scope db = getTempLevelDb();
  assert(!db.closed());
}

unittest
{
  scope db = getTempLevelDb();
  foreach(image; db.imageDataIterator())
  {
    assert(false);
  }
}

unittest
{
  scope db = getTempLevelDb();
  auto img_data = imageFromFile("test/cat_a1.jpg");

  auto image_id = db.addImage(&img_data);
  assert(db.imageDataIterator().empty == false);
}

unittest
{
  scope db = getTempLevelDb();
  auto img_data = imageFromFile("test/cat_a1.jpg");

  auto image_id = db.addImage(&img_data);

  bool iterated = false;
  foreach(image; db.imageDataIterator())
  {
    iterated = true;
    assert(image.user_id == image_id);
    assert(image.sig == img_data.sig);
    assert(image.dc == img_data.dc);
    assert(image.res == img_data.res);
  }

  assert(iterated);
}

unittest
{
  scope db = getTempLevelDb();
  auto img_data = imageFromFile("test/cat_a1.jpg");

  assert(db.numImages() == 0);
  auto image_id = db.addImage(&img_data);

  auto memdb = db.releaseMemDb();
  assert(memdb.numImages() == 1);
}
