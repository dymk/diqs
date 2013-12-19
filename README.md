DIQS - D Image Query Server
===========================
`~master`: [![Build Status](https://travis-ci.org/dymk/diqs.png?branch=master)](https://travis-ci.org/dymk/diqs)

`~develop`: [![Build Status](https://travis-ci.org/dymk/diqs.png?branch=develop)](https://travis-ci.org/dymk/diqs)

> **Note**: Right now, this is alpha level software, although it seems to work
fairly reliably right now. Expect sharp corners, a fire in the server room, and
ants to crawl out of your keyboard if you use this in production.

DIQS is a set of tools for determining how visually similar images are. Its aim is to
be both _high speed_, and have a _small memory footprint_. It currently
consists of two components: A server, and a client binary. The server is
responsible for the creation/loading/modification/querying of file backed
databases on the disk. The client provides a command line interface for
interacting with the server, over a network protocol described in `src/net/payload.d`.
The server can have multiple databases open at once, as well as interact with
multiple clients at a time.

Images in a database are associated with an immutable ID, which
is used for removing the image from the database, and to refer to it in query
results. It's refered to as the 'user_id', as it is the user facing ID of the image.

DIQS is my first experementation in writing medium sized, networked applications
in D. If you run into issues, please let me know in the [bug tracker](https://github.com/dymk/diqs/issues).

I've usually got some neat stuff happening in the `~develop` branch, so check that out,
and your build will either horribly break, gain some neat new feature/optlimization, or a
combination of both!

1: Configuration
----------------

DIQS depends on ImageMagick dev package for your system, and has been tested with
version `ImageMagick-6.8.6-Q16`.

It also requires Google's LevelDb, a simple key-value store, which can be found at
[https://code.google.com/p/leveldb/](https://code.google.com/p/leveldb/).
It has been tested with version 0.19.0.

DIQS was tested with DMD version 2.064.2, and `~master` of LDC. There's a good
chance that it'll work just fine with GDC though, and possible 2.063 of DMD. If you
run into compiler errors, try changing around the DC flags in the makefile;
release and unittest tend to break the most often due to compiler changes. Chances
are it'll compile and work just fine on Windows, but YMMV.

2: Compilation
--------------

`make` to make, by default, the `debug` versions of the client/server
 * `make debug`: Build with debug information
 * `make release`: Build release
 * `make unittest`: Build (& run) the test runner
 * `make unittest_diskio`: Build (& run) the test runner, and also test functions that perform file I/O (which makes tests slower)

If you get linker errors on POSIX, make sure that the `MagickCore` and
`MagickWand` libraries are installed.

To compile with another D compiler, tack on a `DC=ldmd2` or whatever might suit you.

3: Running
----------

You should now have a `server` and `client` binary. The `client` will
connect to an active server on a given port, at which point the client can perform
server administration such as adding or removing images, loading/unloading/flushing
databases, or querying images. Running either binary with the `-h` flag will
print the command line options that they take.

Start a server by running `server`, with an additional `p|port` argument to
specify which port the server runs on (the default is 9548), or the address to
bind to (the default of which is 127.0.0.1). Multiple servers can run on
on a single computer, and servers can have multiple databases loaded at
one time.

Databases on the server are referenced with an opaque database id (DBID or db_id in the code),
which changes depending on the order that databases are loaded by the server.

Here's a list of supported client commands, as per the `help` command:

```
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
```

Paths sent to the server are assume to be relative to the current working
directory of the server (not from where the client is running)

Type the path of an image to get its score in comparison with the images
now in the database.
Results are in the format `ID: <id> : <similarity>%`, where similarity
is a percent.

The Temporary Format of Client Output
-------------------------------------

Client output is in a state of flux right now, and only batch image insertion
and querying has a semi-easy parseable output.

Because there isn't a dedicated tool for inserting images yet, I recommend
adding images using a command like this to capture the mapping of
image paths to IDs:

```
echo "addImageBatch <image_directory> <db_id>" | ./client > id_map_file
```

### addImageBatch
On success:
  `s::<path>::<db_id>::<image_id>`

On failure:
  `f::<path>::<db_id>::<code>`

Where `path` is the path of the image added, `db_id` is the ID of the database
that did (or tried to) insert the image, `image_id` is the ID of the image after
insertion, and `code` is the error code returned by the server if the insertion
failed.

### queryImage
On success:
  `ID:   <id> | Sim: <sim> | Res: <res>` where `<id>` is the image's `user_id`,
  `<sim>` is a floating point percentage visual similarity, and `res` is the
  resulution of the image in `widthXheight` format.
  Sample: `ID:   484146 | Sim: 53.19 | Res: 64x64`

On failure:
  `Failure | <error>` where `<error>` is the error that prevented the query from
  completing.
  Sample: `Failure | NonExistantFile`

Todo
----
  * ~~MySQL/PG persistance layer adapter~~ _LevelDb backed store implemented_
  * ~~Network protocol for running DIQS as an actual server~~ _Basic multiclient server and client implemented_
  * Create only in memory databases (lower overhead than file backed DBs) _Next Up_
  * Distribute file databases across multiple clients (parallelize lookup, or
    allow clustering of slaves across several low power machines) _Requires memory-only databases first_
  * Loading bar for loading large databases (should be trivial)


Optimizations that need to happen (more than they already have):
  * ~~Store bucket sizes in LevelDb.~~ _Done_
  * Profile database querying (mostly needs to be made multithreaded)
  * B&W Image Optimizations (less storage needed + faster query times)

_Many thanks to piespy, Xamayon, and dovac in #iqdb_

_Distributed under the terms and conditions of "I dunno, I'll figure
it out later"._

_Authored by [dymk](https://www.github.com/dymk/) - tcdknutson@gmail.com_
