module magick_wand.wand;

import magick_wand;

import std.string;
import std.exception : enforce;
import core.memory : GC;

// "magick-wand-private.h", line 33
class MagickWand {
	private WandPtr wandPtr = null;
	this()
	{
		wandPtr = NewMagickWand();
	}

	~this()
	{
		DestroyMagickWand(wandPtr);
	}

	auto readImage(string fname)
	{
		return this.wandPtr.MagickReadImage(fname.toStringz());
	}

	auto imageWidth()   { return this.wandPtr.MagickGetImageWidth(); }
	auto imageHeight()  { return this.wandPtr.MagickGetImageHeight(); }
	auto clear()        { return this.wandPtr.ClearMagickWand(); }
	auto isMagickWand() { return this.wandPtr.IsMagickWand(); }
	auto resizeImage(size_t cols, size_t rows, FilterTypes filter, double blur)
	{
		return this.wandPtr.MagickResizeImage(cols, rows, filter, blur);
	}

	auto exportImagePixels(T)(
		size_t x = 0, size_t y = 0)
	{
		return exportImagePixels!(T)(x, y, this.imageWidth(), this.imageHeight());
	}

	auto exportImagePixels(T)(
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

	auto exportImagePixelsFlat(T)(
		size_t x = 0, size_t y = 0)
	{
		return exportImagePixelsFlat!(T)(x, y, this.imageWidth(), this.imageHeight());
	}

	auto exportImagePixelsFlat(T)(
		size_t x, size_t y, size_t cols, size_t rows)
	{
		enforce(x <= cols);
		enforce(y <= rows);
		enforce(x + cols <= this.imageWidth());
		enforce(y + rows <= this.imageHeight());

		enforce(T.sizeof == RGB.sizeof);

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
};

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
