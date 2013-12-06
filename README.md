DIQS - D Image Query Server
---------------------------
By dymk - _tcdknutson@gmail.com_

> **Note**: Right now, this is alpha level software. Expect sharp corners,
a fire in the server room, and ants to crawl out of your keyboard.

_Many thanks to piespy, Xamayon, and dovac in #iqdb_

_Distributed under the terms and conditions of "I dunno, I'll figure
it out later"._

1: Configuration
----------------

You'll need the ImageMagick dev package for your system. DIQS has been
tested and ships with the export library files for `ImageMagick-6.8.6-Q16`.

DIQS was tested with DMD version 2.063, and the `~master` of LDC. There's a good
chance that it'll work just fine with GDC though. If you run into compiler
errors, try chaning around the DC flags in the makefile; release and unittest
tend to break the most often due to compiler changes.

2: Compilation
--------------

`make` to make, by default, the `debug` versions of the client/server
`make <config>` to make a specific configurtion, where `config` is one of:
 * `debug`: Build with debug informatoin
 * `release`: Build release
 * `unittest`: Build (& run) the test runner
 * `unittest_diskio` Build (& run) the test runner, and also test functions that perform file I/O (which makes tests slower)

If you get linker errors on posix, make sure that the `MagickCore` and
`MagickWand` libraries are being linked (see `src/magick_wand/all.d`).

3: Running
----------

You should now have a `server` and `client` binary. The `client` will
connect to an active server on a given port, at which point one can perform
server administration such as adding or removing images, loading/unloading/flushing
databases, or querying images. Running either binary with the `-h` flag will
print the command line options that they take.

Start a server by running `server`, with an additional `p|port` argument to
specify which port the server runs on (the default is 9548), or the address to
bind to (the default of which is 127.0.0.1). Multiple servers can run on
on a single computer, and servers can have multiple databases loaded at
one time.

Databases on the server are referenced with an opaque database id (DBID or db_id in the code)

Here's a list of supported client commands, as per the `help` command:

```
  help
    Print this help

  lsDbs
    List the databases available on the server

  loadFileDb PATH [CREATE_IF_NOT_EXIST]
    Loads a file database on the server at PATH. Fails if the database
    does not exist. If CREATE_IF_NOT_EXIST is 1, then the database is
    created if it doesn't exist.

  createFileDb PATH
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

  addImageBatch PATH DBID
    Adds a set of images to the database, where PATH is the path
    to a folder of images.

  queryImage PATH DBID [NUM_RESULTS = 10]
    Perform a similarity query, listing the top NUM_RESULTS matches.

  shutdown
    Shuts down the server and closes all connections
```

Paths sent to the server are assume to be relative to the current working
directory of the server (not from where the client is running)

Type the path of an image to get its score in comparison with the images
now in the database.
Results are in the format `ID: <id> : <similarity>%`, where similarity
is a percent.

Format of Client Output
=======================

Client output is in a state of flux right now, and only batch image insertion
into a database has an easily parsable output.

### addImageBatch
On success:
  `s::<path>::<db_id>::<image_id>`

On failure:
  `f::<path>::<db_id>::<code>`

Where `path` is the path of the image added, `db_id` is the ID of the database
that did (or tried to) insert the image, `image_id` is the ID of the image after
insertion, and `code` is the error code returned by the server if the insertion
failed.

Todo
====
 - Create only in memory databases (lower overhead than file backed DBs)
 - Distribute file databases across multiple clients (parallelize lookup, or
   allow clustering of slaves across several low power machines)
 - MySQL/PG persistance layer adapter
 - Loading bar for loading large databases (should be trivial)
 - Network protocol for running DIQS as an actual server

In OnDiskPersistance:
 - Break up database into multiple files, perhaps for parallelized
loading from the disk?

Optimizations that need to happen (more than they already have):
 - Profile large database loading (Takes ~5 seconds to load a 100K image db).
 - Profile database querying
 - B&W Image Optimizations (less storage needed + faster query times)
