module sig;

/**
 * Image signature types and methods for calculating an image's signature
 */

import consts :
	NumSigCoeffs,
	NumColorChans,
	ImageHeight,
	ImageWidth;

import magick_wand :
	MagickWand,
	FilterTypes,
	YIQ;

import types :
	coeffi_t,
	coeff_t,
	sig_t,
	dc_t,
	res_t,
	image_id_t;

import haar : haar2d;
import util : largestCoeffs;

import std.exception : enforce;
import std.algorithm : map, copy;
import std.range : array;
import std.string : format;
import core.memory : GC;

struct CoeffIPair
{
	coeffi_t index;
	coeff_t  coeff;

	string toString() {
		return format("i: %d, c: %f", index, coeff);
	}
}

/**
 * Structs to represent image data in memory, and on the
 * disk.
 */
struct ImageSig
{
	// Locations of the top NumSigCoeffs coefficients
	sig_t[NumColorChans] sigs;
	ref auto y() @property { return sigs[0]; }
	ref auto i() @property { return sigs[1]; }
	ref auto q() @property { return sigs[2]; }
}

struct ImageDC
{
	// DC coefficents (first component) of the haar decomposed image
	dc_t y, i, q;
}

struct ImageRes
{
	res_t width, height;
}

struct ImageData
{
	ImageSig sig;
	ImageDC dc;
	ImageRes res;

	static auto fromFile(string file)
	{
		auto ret = ImageData();
		scope wand = new MagickWand();
		enforce(wand.readImage(file));
		short
		  width = cast(res_t)wand.imageWidth(),
		  height = cast(res_t)wand.imageHeight();
		ret.res = ImageRes(width, height);

		enforce(wand.resizeImage(ImageWidth, ImageHeight, FilterTypes.LanczosFilter, 1.0));
		scope pixels = wand.exportImagePixelsFlat!YIQ();
		enforce(pixels);

		scope ychan = pixels.map!(a => cast(coeff_t)a.y).array();
		scope ichan = pixels.map!(a => cast(coeff_t)a.i).array();
		scope qchan = pixels.map!(a => cast(coeff_t)a.q).array();

		haar2d(ychan, ImageWidth, ImageHeight);
		haar2d(ichan, ImageWidth, ImageHeight);
		haar2d(qchan, ImageWidth, ImageHeight);

		ret.dc = ImageDC(ychan[0], ichan[0], qchan[0]);

		scope ylargest = largestCoeffs(ychan[1..$], NumSigCoeffs);
		scope ilargest = largestCoeffs(ichan[1..$], NumSigCoeffs);
		scope qlargest = largestCoeffs(qchan[1..$], NumSigCoeffs);

		auto sig = ImageSig();
		ylargest.map!(a => a.index)().copy(sig.y[]);
		ilargest.map!(a => a.index)().copy(sig.i[]);
		qlargest.map!(a => a.index)().copy(sig.q[]);
		ret.sig = sig;

		return ret;
	}
}

unittest {
	auto i = ImageData.fromFile("test/white_line_10px_bmp.bmp");
	assert(i.res == ImageRes(10, 1));
	assert(i.dc != ImageDC.init);
	assert(i.sig != ImageSig.init);
}

/// For now, used when serializing image data to the disk
/// so an immutable user ID can be associated with it
struct IDImageData
{
	image_id_t user_id;
	ImageSig sig;
	ImageDC dc;
	ImageRes res;
}
