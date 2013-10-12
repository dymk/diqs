module magick_wand.wand;

import magick_wand.all;

import std.string;
import std.exception : enforce, enforceEx;
import core.memory : GC;

class WandException : Exception {
	this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
};
final class InvalidImageException : WandException {
	this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
};
final class CantResizeImageException : WandException {
	this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
}
final class CantExportPixelsException : WandException {
	this(string message = "Couldn't export image pixels", string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
}
final class CantImportPixelsException : WandException {
	this(string message = "Couldn't import image pixels", string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
}
final class NonExistantFileException : WandException {
	this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
}
final class CantCreateNewImageException : WandException {
	this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null) { super(message, file, line, next); }
}

//shared static this() {
//	MagickWandGenesis();
//}
//shared static ~this() {
//	MagickWandTerminus();
//}

// "magick-wand-private.h", line 33
class MagickWand {

	// somethingEx functions are throwing functions, which
	// enforce the success of the underlying function they call.

	this()
	{
		wandPtr = NewMagickWand();
	}

	~this()
	{
		DestroyMagickWand(wandPtr);
	}

	bool readImageEx(string fname)
	{
		import std.file : exists;
		if(!exists(fname))
			throw new NonExistantFileException("File " ~ fname ~ " does not exist");
		return enforceEx!InvalidImageException(readImage(fname), "Couldn't open image file: " ~ fname);
	}
	bool readImage(string fname)
	{
		return MagickReadImage(this.wandPtr, fname.toStringz());
	}

	auto imageWidth()   { return this.wandPtr.MagickGetImageWidth(); }
	auto imageHeight()  { return this.wandPtr.MagickGetImageHeight(); }
	auto clear()        { return this.wandPtr.ClearMagickWand(); }
	auto isMagickWand() { return this.wandPtr.IsMagickWand(); }

	auto scaleImageEx(size_t cols, size_t rows)
	{
		return enforceEx!CantResizeImageException(scaleImage(cols, rows), "Couldn't resize image");
	}
	auto scaleImage(size_t cols, size_t rows)
	{
		return this.wandPtr.MagickScaleImage(cols, rows);
	}
	auto resizeImage(size_t cols, size_t rows, FilterTypes filter, double blur)
	{
		return this.wandPtr.MagickResizeImage(cols, rows, filter, blur);
	}

	auto newImageEx(size_t cols, size_t rows, PixelWand px_wand = null)
	{
		return enforceEx!CantCreateNewImageException(newImage(cols, rows, px_wand));
	}

	auto newImage(size_t cols, size_t rows, PixelWand px_wand = null)
	{
		bool shouldDestroy = px_wand is null;

		if(shouldDestroy) {
			px_wand = new PixelWand();
		}

		scope(exit) {
			if(shouldDestroy) {
				px_wand.destroy();
				GC.free(cast(void*)px_wand);
			}
		}

		return this.wandPtr.MagickNewImage(cols, rows, px_wand.ptr());
	}

	auto getNumberImages()
	{
		return this.wandPtr.MagickGetNumberImages();
	}

	auto getException(ExceptionType* ex_type = null) {
		ExceptionType tmp;

		if(ex_type is null) {
			ex_type = &tmp;
		}

		char* err_str = this.wandPtr.MagickGetException(ex_type);
		scope(exit) {
			import core.stdc.stdlib;
			free(cast(void*)err_str);
		}

		import std.conv : to;
		string ret = to!string(err_str);

		return ret;
	}

	auto exportImagePixelsEx(T)(
		size_t x = 0, size_t y = 0)
	{
		return enforceEx!CantExportPixelsException(exportImagePixels!(T)(x, y));
	}

	T[][] exportImagePixelsEx(T)(
		size_t x, size_t y, size_t cols, size_t rows)
	{
		return enforceEx!CantExportPixelsException(exportImagePixels!(T)(x, y, cols, rows));
	}

	T[][] exportImagePixels(T)(
		size_t x = 0, size_t y = 0)
	{
		return exportImagePixels!(T)(x, y, this.imageWidth(), this.imageHeight());
	}

	T[][] exportImagePixels(T)(
		size_t x, size_t y, size_t cols, size_t rows)
	{
		auto height = rows - y;
		auto width = cols - x;
		auto pxbuffer = exportImagePixelsFlat!(T)(x, y, cols, rows);

		if(pxbuffer is null) {
			return null;
		} else {
			auto mat = new T[][height];
			foreach(h; 0..height) {
				mat[h] = pxbuffer[h*width .. (h+1)*width];
			}
			return mat;
		}
	}

	T[] exportImagePixelsFlatEx(T)(
		size_t x = 0, size_t y = 0)
	{
		return enforceEx!CantExportPixelsException(exportImagePixelsFlat!(T)(x, y));
	}

	T[] exportImagePixelsFlatEx(T)(
		size_t x, size_t y, size_t cols, size_t rows)
	{
		return enforceEx!CantExportPixelsException(exportImagePixelsFlat!(T)(x, y, cols, rows));
	}

	T[] exportImagePixelsFlat(T)(
		size_t x = 0, size_t y = 0)
	{
		return exportImagePixelsFlat!(T)(x, y, this.imageWidth(), this.imageHeight());
	}

	T[] exportImagePixelsFlat(T)(
		size_t x, size_t y, size_t cols, size_t rows)
	{
		static assert(T.sizeof == RGB.sizeof);

		enforce(x <= cols);
		enforce(y <= rows);
		enforce(x + cols <= this.imageWidth());
		enforce(y + rows <= this.imageHeight());

		auto area = (rows - y)*(cols - x);
		auto pxbuffer = new RGB[area];

		bool success = this.wandPtr.MagickExportImagePixels(
			0, 0, cols, rows, "RGB".toStringz(),
			StorageType.CharPixel, pxbuffer.ptr);

		if(success) {

			// Do an in place transform of all data
			// this should be safe because we've ensured
			// that T.sizeof == RGB.sizeof
			T[] t_pxbuffer = cast(T[])pxbuffer;
			foreach(i; 0..area) {
				t_pxbuffer[i] = T.from_rgb(pxbuffer[i]);
			}
			return t_pxbuffer;

		} else {
			GC.free(pxbuffer.ptr);
			return null;
		}
	}

	bool importImagePixelsFlatEx(T)(
		size_t cols, size_t rows, T[] pixels
	) {
		return enforceEx!CantImportPixelsException(importImagePixelsFlat!T(cols, rows, pixels));
	}

	bool importImagePixelsFlatEx(T)(size_t x, size_t y, size_t cols, size_t rows, T[] pixels)
	{
		return enforceEx!CantImportPixelsException(importImagePixelsFlat!T(x, y, cols, rows, pixels));
	}

	bool importImagePixelsFlat(T)(size_t cols, size_t rows, T[] pixels) {
		return importImagePixelsFlat!T(0, 0, cols, rows, pixels);
	}

	bool importImagePixelsFlat(T)(size_t x, size_t y, size_t cols, size_t rows, T[] pixels)
	{
		static assert(T.sizeof == RGB.sizeof);

		enforce(x <= cols);
		enforce(y <= rows);

		size_t area = (cols - x) * (rows - y);
		enforce(area == pixels.length);

		static if(is(T == RGB))
		{
			auto pxbuffer = pixels;
		}
		else
		{
			auto pxbuffer = new RGB[pixels.length];
			scope(exit) { GC.free(pxbuffer.ptr); }

			foreach(i; 0..pixels.length)
			{
				pxbuffer[i] = pixels[i].toRGB();
			}
		}

		return this.wandPtr.MagickImportImagePixels(
			x, y, cols, rows, "RGB".toStringz(),
			StorageType.CharPixel, pxbuffer.ptr);
	}

	// Flyweight pattern to avoid needless allocations
	static getWand() {
		if(disposedWands.length == 0)
		{
			return new MagickWand();
		}
		else
		{
			auto w = disposedWands[$-1];
			disposedWands.length--;
			return w;
		}
	}
	static disposeWand(MagickWand wand) {
		wand.clear();
		disposedWands ~= wand;
	}

	// Helper method to create a wand from a file image
	static fromFile(string file) {
		auto wand = getWand();
		wand.readImageEx(file);
		return wand;
	}

private:
	static MagickWand[] disposedWands;
	WandPtr wandPtr = null;
}

// isMagickWand
unittest {
	scope wand = new MagickWand;
	assert(wand.isMagickWand());
}

// readImage
unittest {
	scope wand = new MagickWand;
	assert(wand.readImage("test/small_bmp.bmp") == true);
}
unittest {
	scope wand = new MagickWand;
	assert(wand.readImage("test/nonexistant.jpg") == false);
}

unittest {
	scope wand = new MagickWand;
	assert(wand.getNumberImages() == 0);
	wand.readImageEx("test/small_bmp.bmp");
	assert(wand.getNumberImages() == 1);
}

// imageWidth
unittest {
	scope wand = new MagickWand;
	assert(wand.readImage("test/white_line_10px_bmp.bmp") == true);
	assert(wand.imageWidth() == 10);
}

// imageHeight
unittest {
	scope wand = new MagickWand;
	assert(wand.readImage("test/white_line_10px_bmp.bmp") == true);
	assert(wand.imageHeight() == 1);
}

// exportImagePixelsFlat
unittest {
	scope wand = new MagickWand;
	assert(wand.readImage("test/white_line_10px_bmp.bmp") == true);
	scope px = wand.exportImagePixelsFlat!(RGB)();
	assert(px.length == 10);
	foreach(p; px) {
		assert(p == RGB(255, 255, 255));
	}
}

// exportImagePixels
unittest {
	scope wand = new MagickWand;
	assert(wand.readImage("test/white_line_10px_bmp.bmp") == true);
	scope px = wand.exportImagePixels!(RGB)();
	assert(px.length == 1);
	assert(px[0].length == 10);
	foreach(p; px[0]) {
		assert(p == RGB(255, 255, 255));
	}
}

// newImage
unittest {
	scope wand = new MagickWand;
	assert(wand.newImage(10, 5));
	assert(wand.imageWidth() == 10);
	assert(wand.imageHeight() == 5);
}

// importImagePixelsFlat
unittest {
	auto pixels = [RGB(0, 4, 23), RGB(0, 0, 0), RGB(0, 0, 0)];

	scope wand = new MagickWand;
	assert(wand.newImage(1, 3));

	assert(wand.importImagePixelsFlat(1, 3, pixels));

	assert(wand.imageWidth() == 1);
	assert(wand.imageHeight() == 3);

	assert(wand.exportImagePixelsFlat!RGB() == pixels);
}
