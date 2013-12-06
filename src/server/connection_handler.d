module server.connection_handler;

import types;
import sig;
import query;

import net.payload;
import net.common;
import magick_wand.wand;
import image_db.file_db;
import image_db.mem_db;
import image_db.persisted_db;
import image_db.base_db;

import server.server;
import server.context;

import std.stdio;
import std.variant;
import std.concurrency;
import std.socket;
import std.getopt : getopt;
import std.range : array;
import core.time : dur;

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
      (RequestLoadFileDb req)     { return handleOpeningFileDatabase(req, context);  },
      (RequestCreateFileDb req)   { return handleOpeningFileDatabase(req, context);  },
      (RequestAddImageFromPath req)
                                  { return handleAddImageFromPath(req, context);     },
      (RequestAddImageFromPixels req)
                                  { return handleAddImageFromPixels(req, context);   },
      (RequestQueryFromPath req)  { return handleQueryFromPath(req, context);        },
      (RequestFlushDb req)        { return handleFlushDb(req, context);              },
      ()
      {
        return Payload(ResponseFailure(ResponseFailure.Code.UnknownPayload));
      }
    )();
  }
  catch(DatabaseNotFoundException e) {
    response = ResponseFailure(ResponseFailure.Code.DbNotFound);
  }

  catch(magick_wand.wand.NonExistantFileException e) {
    response = ResponseFailure(ResponseFailure.Code.NonExistantFile);
  }

  catch(magick_wand.wand.InvalidImageException e) {
    response = ResponseFailure(ResponseFailure.Code.InvalidImage);
  }

  catch(magick_wand.wand.CantResizeImageException e) {
    response = ResponseFailure(ResponseFailure.Code.CantResizeImage);
  }

  catch(magick_wand.wand.CantExportPixelsException e) {
    response = ResponseFailure(ResponseFailure.Code.CantExportPixels);
  }

  catch(FileDb.DbFileAlreadyExistsException e) {
    response = ResponseFailure(ResponseFailure.Code.DbFileAlreadyExists);
  }

  catch(FileDb.DbFileNotFoundException e) {
    response = ResponseFailure(ResponseFailure.Code.DbFileNotFound);
  }

  catch(Exception e) {
    writefln("Failure; Caught exception: %s (msg: %s)", e, e.msg);
    response = ResponseFailure(ResponseFailure.Code.UnknownException);
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

Payload handleOpeningFileDatabase(R)(R req, Context context)
{

  writefln("Got load/create request for DB at '%s'", req.db_path);

  FileDb db;

  static if(is(R == RequestCreateFileDb))
  {
    db = FileDb.createFromFile(req.db_path);
    writefln("Created database at path %s", req.db_path);
  }
  else static if(is(R == RequestLoadFileDb))
  {
    if(context.fileDbIsLoaded(req.db_path))
    {
      return Payload(ResponseFailure(ResponseFailure.Code.DbAlreadyLoaded));
    }

    db = FileDb.loadFromFile(req.db_path, req.create_if_not_exist);
    writefln("Loaded database at path %s", req.db_path);
  }
  else
    static assert(false, "Request type must be LoadFileDb or CreateFileDb");


  auto db_id = context.addDb(DbType(db));
  return Payload(ResponseDbInfo(db_id, db));
}

// Generic add image data from request and image data
Payload addImageData(Req)(ImageSigDcRes image_data, Req req, Context context)
if(
  is(Req == RequestAddImageFromPath) ||
  is(Req == RequestAddImageFromPixels))
{
  BaseDb bdb = context.getDbEx(req.db_id);

  user_id_t image_id;
  if(req.use_image_id)
  {
    image_id = req.image_id;
  } else
  {
    image_id = bdb.peekNextId();
  }

  try
  {
    bdb.addImage(image_data, image_id);
  }
  catch(BaseDb.AlreadyHaveIdException)
  {
    return Payload(ResponseFailure(ResponseFailure.Code.AlreadyHaveId));
  }

  return Payload(ResponseImageAdded(req.db_id, image_id));
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

  return addImageData(image_data, req, context);
}

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

  return addImageData(image_data, req, context);
}

Payload handleQueryFromPath(RequestQueryFromPath req, Context context)
{
  BaseDb db = context.getDbEx(req.db_id);

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


  auto query_results = db.query(qp);
  scope(exit) { GC.free(query_results.ptr); }

  auto resp_results = query_results.map!(
    (result) {
      return ResponseQueryResults.QueryResult(
        result.image.user_id,
        result.similarity,
        result.image.res);
    }
  )().array();
  //scope(exit) { GC.free(resp_results.ptr); }

  return Payload(ResponseQueryResults(resp_results));
}

Payload handleFlushDb(RequestFlushDb req, Context context)
{
  user_id_t db_id = req.db_id;
  auto db = cast(PersistedDb) context.getDbEx(db_id);

  if(db is null)
  {
    return Payload(ResponseUnpersistableDb(db_id));
  }

  db.flush();
  return Payload(ResponseSuccess());
}