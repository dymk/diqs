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

DIQS was tested with DMD version 2.063, and the `~master` of LDC.

2: Compilation
--------------

Run the `Makefile`. If you're on Linux or OSX, then use `posix.mak`.
Chances are the Windows makefile works just fine. The posix one;
probably not so much. If `posix.mak` fails to compile, twiddle some
bits and look to `Makefile` for insparation. Compilation is pretty
straightforwad, just throw all of the files on the command line
for your compiler, and supply the ImageMagic and MagicCore libraries.

If you get linker errors on posix, make sure that the `MagickCore` and
`MagickWand` libraries are being linked (see `src/magick_wand/all.d`).

3: Running
----------

You should now have a `diqs` binary. DIQS doesn't do a whole lot at
this point, and is mostly a half-assed CLI on top of a more or less
functional yet unstable backend.

**Everything past this point just shows demo functionality of the application.**

> Note: You'll need to create the directory `src/test/ignore`, as that
is currently the hardcoded path that new databases are created under.
This was a stopgap to make sure that no critical files were overwritten
in case the program did something unexpected. The behavior will change
as stability gets better, and frontend features are added.

After running, you'll be prompted with the message
```
    Database name:
    >
```
DIQS will create a new database, or open an existing one. The file
will be created under `src/test/ignore` (yes, this will change later).

If you create a new database, you'll then be promted to load a directory
of images. Enter a folder which contains images, and they'll be loaded
into the database. As images are being loaded into the db, their ID and
file path will be printed to `stderr` in the format of `ID:filepath`.

The next prompt will be
```
    Enter image path to compare:
    >
```

Type the path of an image to get its score in comparison with the images
now in the database.
Results are in the format `ID: <id> : <similarity>%`, where similarity
is a percent.
