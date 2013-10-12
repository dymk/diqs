module magick_wand.pixel;

import magick_wand.all;

import std.string;
import std.exception : enforce, enforceEx;
import core.memory : GC;

class PixelWand {

	this() {
		pixelWandPtr = NewPixelWand();
		PixelSetRed(pixelWandPtr, 1);
		PixelSetGreen(pixelWandPtr, 1);
		PixelSetBlue(pixelWandPtr, 1);
	}

	~this() {
		DestroyPixelWand(pixelWandPtr);
	}

	PixelWandPtr ptr() { return pixelWandPtr; }

private:
	PixelWandPtr pixelWandPtr;
}
