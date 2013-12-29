module server.connection_handler;

import types;
import sig;
import query;
import consts;

import net.payload;
import net.common;
import magick_wand.wand;
import image_db.all;

import server.server;
import server.context;

import std.stdio;
import std.variant;
import std.concurrency;
import std.socket;
import std.file;
import std.parallelism : taskPool;
import std.datetime : StopWatch;
import std.getopt : getopt;
import std.range : array;
import core.time : dur;
import core.atomic;

void handleClientRequest(Socket conn, Context context)
{
  Payload request = conn.readPayload();

  writefln("Client sent request %s", request);

  Payload response;

  try
  {
    response = request.tryVisit!(
      handleRequestPing,
      handleRequestVersion,
      (RequestServerShutdown req) { return handleRequestShutdown(req, context);      },
      (RequestListDatabases req)  { return handleRequestListDatabases(req, context); },
      (RequestLoadLevelDb req)     { return handleOpeningLevelDatabase(req, context);},
      (RequestCreateLevelDb req)   { return handleOpeningLevelDatabase(req, context);},
      (RequestAddImageFromPath req)
                                  { return handleAddImageFromPath(req, context);     },
      (RequestAddImageFromPixels req)
                                  { return handleAddImageFromPixels(req, context);   },
      (RequestQueryFromPath req)  { return handleQueryFromPath(req, context);        },
      (RequestFlushDb req)        { return handleFlushDb(req, context);              },
      (RequestAddImageBatch req)  { return handleAddImageBatch(req, context, conn);  },
      //(RequestExportMemDb req)    { return handleExportMemDb(req, context);          },
      (RequestCreateMemDb req)    { return handleCreateMemDb(req, context);          },
      (RequestMakeQueryable req)  { return handleMakeQueryable(req, context);        },
      (RequestDestroyQueryable req){ return handleDestroyQueryable(req, context);    },
      (RequestRemoveImage req)    { return handleRemoveImage(req, context);          },
      (RequestCloseDb req)        { return handleClosedb(req, context);              },
      ()
      {
        return Payload(ResponseFailure(ErrorCode.UnknownPayload));
      }
    )();
  }
  catch(BaseDb.IdNotFoundException e) {
    response = ResponseFailure(ErrorCode.IdNotFound);
  }

  catch(BaseDb.AlreadyHaveIdException e)
  {
    response = ResponseFailure(ErrorCode.AlreadyHaveId);
  }

  catch(PersistableDb.DbNonexistantException e) {
    response = ResponseFailure(ErrorCode.DbNonexistant);
  }

  catch(Context.DbNotLoadedException e) {
    response = ResponseFailure(ErrorCode.DbNotLoaded);
  }

  catch(magick_wand.wand.NonExistantFileException e) {
    response = ResponseFailure(ErrorCode.NonExistantFile);
  }

  catch(magick_wand.wand.InvalidImageException e) {
    response = ResponseFailure(ErrorCode.InvalidImage);
  }

  catch(magick_wand.wand.CantResizeImageException e) {
    response = ResponseFailure(ErrorCode.CantResizeImage);
  }

  catch(magick_wand.wand.CantExportPixelsException e) {
    response = ResponseFailure(ErrorCode.CantExportPixels);
  }

  catch(PayloadSocketClosedException e) {
    writefln("Client closed the connection");
    return;
  }

  catch(Exception e) {
    writefln("Failure; Caught exception: %s (msg: %s)", e, e.msg);
    response = ResponseFailure(ErrorCode.UnknownException);
  }

  enforce(response.hasValue(),
    "Internal error; response type wasn't determined for this request");

  writefln("Responding with: %s", response);
  conn.writePayload(response);
}

Payload handleRequestPing(RequestPing req)
{
  return Payload(ResponsePong());
}

Payload handleRequestVersion(RequestVersion req)
{
  return Payload(ServerVersion);
}

Payload handleRequestShutdown(RequestServerShutdown req, Context context)
{
  context.server_running = false;
  return Payload(ResponseServerShutdown());
}

Payload handleRequestListDatabases(RequestListDatabases req, Context context)
{
  auto list = context.listDbInfo();
  return Payload(ResponseListDatabases(list));
}

Payload handleOpeningLevelDatabase(R)(R req, Context context)
{

  writefln("Got load/create request for DB at '%s'", req.db_path);

  LevelDb db;

  static if(is(R == RequestCreateLevelDb))
  {
    writefln("Creating database at path %s", req.db_path);
    bool create_if_not_exist = true;
  }
  else static if(is(R == RequestLoadLevelDb))
  {
    writefln("Loading database at path %s", req.db_path);
    bool create_if_not_exist = req.create_if_not_exist;
  }
  else
    static assert(false, "Request type must be LoadLevelDb or CreateLevelDb");

  db = new LevelDb(req.db_path, create_if_not_exist);

  auto db_id = context.addDb(DbType(cast(PersistableDb) db));
  return Payload(ResponseDbInfo(db_id, db));
}

// Generic add image data from request and image data
Payload addImageData(Req)(const(ImageSigDcRes*) image_data, Req req, Context context)
if(
  is(Req == RequestAddImageFromPath) ||
  is(Req == RequestAddImageFromPixels))
{
  BaseDb bdb = context.getDbEx(req.db_id);

  user_id_t image_id;
  if(req.use_image_id)
  {
    image_id = bdb.addImage(req.image_id, image_data);
  } else
  {
    image_id = bdb.addImage(image_data);
  }

  return Payload(ResponseImageAdded(image_id));
}

Payload handleAddImageFromPath(RequestAddImageFromPath req, Context context)
{
  writefln("Got add image from path request: %s (dbid: %d, use id? %s, id: %d)",
    req.image_path, req.db_id, req.use_image_id, req.image_id);

  // This is an ugly workaround to handle ImageMagick not liking
  // fibers. Perhaps yield this fiber after spawning the thread and
  // sending the path, and then having the spawned thread signal
  // for the fiber to resume? More research required.
  //auto imageDataThreadId = spawn(&genImageDataFunc, thisTid);
  //send(imageDataThreadId, req.image_path);
  //ImageSigDcRes image_data = receiveOnly!ImageSigDcRes();

  // Moved away from a fiber model, get image sigdcres directly
  auto image_data = ImageSigDcRes.fromFile(req.image_path);

  writefln("Processed image data (res %dx%d)",
    image_data.res.width, image_data.res.height);

  return addImageData(&image_data, req, context);
}

// TODO: Remove this?
Payload handleAddImageFromPixels(RequestAddImageFromPixels req, Context context)
{
  writefln("Got add image from pixels request: %s (use id? %s, id: %d)",
    req.db_id, req.use_image_id, req.image_id);

  scope(exit) {
    GC.free(req.pixels.ptr);
  }

  auto wand =   MagickWand.getWand();
  scope(exit) { MagickWand.disposeWand(wand); }

  wand.newImageEx(
    req.pixels_res.width,
    req.pixels_res.height);

  wand.importImagePixelsFlatEx(
    req.pixels_res.width,
    req.pixels_res.height,
    req.pixels);

  writefln("Imported wand; original image res: %dx%d",
    req.original_res.width, req.original_res.height);

  auto image_data = ImageSigDcRes.fromWand(wand);
  image_data.res = req.original_res;

  return addImageData(&image_data, req, context);
}

Payload handleQueryFromPath(RequestQueryFromPath req, Context context)
{
  QueryableDb db = context.getDbEx(req.db_id).getQueryable();

  if(db is null)
  {
    return Payload(ResponseFailure(ErrorCode.UnsupportedDbOperation));
  }

  QueryParams qp;

  scope(exit) {
    GC.free(cast(void*)req.image_path.ptr);
  }

  // Was used in the vibe.d version of the server
  //auto imageDataThreadId = spawn(&genImageDataFunc, thisTid);
  //send(imageDataThreadId, req.image_path);
  //ImageSigDcRes input = receiveOnly!ImageSigDcRes();

  auto input = ImageSigDcRes.fromFile(req.image_path);

  qp.in_image = &input;
  qp.num_results = req.num_results;

  // Start a timer to measure how long a query took to perform
  StopWatch timer;
  timer.start();

  auto query_results = db.query(qp);
  scope(exit) { GC.free(query_results.ptr); }

  auto resp_results = query_results.map!(
    (result) {
      return ResponseQueryResults.QueryResult(
        result.image.user_id,
        result.similarity);
    }
  )().array();

  timer.stop();
  auto elapsedMsec = timer.peek().msecs;

  return Payload(ResponseQueryResults(elapsedMsec, resp_results));
}

Payload handleFlushDb(RequestFlushDb req, Context context)
{
  user_id_t db_id = req.db_id;
  auto db = cast(PersistableDb) context.getDbEx(db_id);

  if(db is null)
  {
    return Payload(ResponseFailure(ErrorCode.UnsupportedDbOperation));
  }

  db.flush();
  return Payload(ResponseSuccess());
}

Payload handleAddImageBatch(RequestAddImageBatch req, Context context, Socket conn)
{
  user_id_t db_id = req.db_id;
  auto db = context.getDbEx(db_id);
  auto persistable_db = cast(PersistableDb) db;

  scope(exit)
  {
    if(persistable_db !is null)
    {
      persistable_db.flush();
    }
  }

  shared int num_added = 0;
  shared int num_failures = 0;
  immutable flush_per_added = req.flush_per_added;

  void batchFailure(string image_path, ErrorCode err_code)
  {
    synchronized(conn)
    {
      conn.writePayload(ResponseFailureBatch(db_id, image_path, err_code));
    }
    atomicOp!"+="(num_failures, 1);

  }

  auto imageFiles()
  {
    return dirEntries(req.folder, "*.{png,jpg,jpeg,gif}", SpanMode.shallow);
  }

  // Try and reserve space in the DB if it supports it
  {
    writeln("Calculating number of images in dir...");
    size_t num_images = 0;
    foreach(img; imageFiles())
    {
      num_images++;
    }

    writeln("Reserving space...");
    ReservableDb rdb = cast(ReservableDb) db;
    if(rdb !is null)
    {
      rdb.reserve(num_images);
    }
    writefln("Adding %d images...", num_images);
  }

  // call dirEntries again because there isn't a way to reset the returned DirIterator
  foreach(image_path; taskPool.parallel(imageFiles()))
  {

    with (ErrorCode)
    try
    {
      auto image_data = ImageSigDcRes.fromFile(image_path);
      user_id_t image_id = db.addImage(&image_data);

      atomicOp!"+="(num_added, 1);
      synchronized(conn)
      {
        conn.writePayload(ResponseImageAddedBatch(db_id, image_id, image_path));
      }

    }
    catch(magick_wand.wand.NonExistantFileException e) {
      batchFailure(image_path, NonExistantFile);
    }

    catch(magick_wand.wand.InvalidImageException e) {
      batchFailure(image_path, InvalidImage);
    }

    catch(magick_wand.wand.CantResizeImageException e) {
      batchFailure(image_path, CantResizeImage);
    }

    catch(magick_wand.wand.CantExportPixelsException e) {
      batchFailure(image_path, CantExportPixels);
    }

  }

  return Payload(ResponseSuccessBatch(db_id, num_added, num_failures));
}

Payload handleClosedb(RequestCloseDb req, Context context)
{
  auto db_id = req.db_id;
  context.destroyDb(db_id);
  return Payload(ResponseSuccess());
}

Payload handleCreateMemDb(RequestCreateMemDb req, Context context)
{
  MemDb db = new MemDb();
  auto id = context.addDb(db);

  return Payload(ResponseDbInfo(id, db));
}

Payload handleMakeQueryable(RequestMakeQueryable req, Context context)
{
  BaseDb db = context.getDbEx(req.db_id);
  PersistableDb pdb = cast(PersistableDb) db;

  if(pdb is null)
  {
    return Payload(ResponseFailure(ErrorCode.UnsupportedDbOperation));
  }

  pdb.makeQueryable();
  return Payload(ResponseSuccess());
}

Payload handleRemoveImage(RequestRemoveImage req, Context context)
{
  BaseDb db = context.getDbEx(req.db_id);
  ImageRemovableDb irdb = cast(ImageRemovableDb) db;

  if(irdb is null)
  {
    return Payload(ResponseFailure(ErrorCode.UnsupportedDbOperation));
  }

  irdb.removeImage(req.image_id);
  return Payload(ResponseSuccess());
}

Payload handleDestroyQueryable(RequestDestroyQueryable req, Context context)
{
  BaseDb db = context.getDbEx(req.db_id);
  PersistableDb pdb = cast(PersistableDb) db;

  if(pdb is null)
  {
    return Payload(ResponseFailure(ErrorCode.UnsupportedDbOperation));
  }

  pdb.destroyQueryable();
  return Payload(ResponseSuccess());
}
