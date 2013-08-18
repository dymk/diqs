module sig;

/**
 * Image signature types and methods for calculating an image's signature
 */

import consts :
	NumSigCoeffs,
	NumColorChans,
	ImageHeight,
	ImageWidth;

import magick_wand.all :
	MagickWand,
	FilterTypes,
	YIQ;

import types :
	coeffi_t,
	coeff_t,
	sig_t,
	dc_t,
	res_t,
	user_id_t;

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

	version(unittest)
	{
		import std.algorithm : sort;

		bool sameAs(in ImageSig other)
		{
			ImageSig o_dup = other;
			ImageSig t_dup = this;

			foreach(i; 0..NumColorChans)
			{
				o_dup.sigs[i][].sort();
				t_dup.sigs[i][].sort();
			}

			return o_dup == t_dup;
		}
	}
}

struct ImageDc
{
	// DC coefficents (first component) of the haar decomposed image
	dc_t y, i, q;
}

struct ImageRes
{
	res_t width, height;
}

struct ImageDcRes
{
	ImageDc dc;
	ImageRes res;
}

struct ImageSigDcRes
{
	ImageSig sig;
	ImageDc dc;
	ImageRes res;

	static auto fromFile(string file)
	out(ret)
	{
		import std.algorithm : filter;
		import std.string;
		// Assert there are no 0 coefficients in the sig
		foreach(sig_t s; ret.sig.sigs) {
			assert(filter!(a => a == 0)(s[]).array().length == 0,
				format("0 coeff found: %s", s[]));
		}
	}
	body
	{
		auto ret = ImageSigDcRes();

		auto wand = MagickWand.getWand();
		scope(exit) {
			MagickWand.disposeWand(wand);
		}

		enforce(wand.readImage(file), "Couldn't read file: " ~ file);
		short
		  width = cast(res_t)wand.imageWidth(),
		  height = cast(res_t)wand.imageHeight();
		ret.res = ImageRes(width, height);

		//enforce(wand.resizeImage(ImageWidth, ImageHeight, FilterTypes.CubicFilter, 1.0));
		enforce(wand.scaleImage(ImageWidth, ImageHeight));
		scope pixels = wand.exportImagePixelsFlat!YIQ();
		enforce(pixels);

		scope ychan = pixels.map!(a => cast(coeff_t)a.y).array();
		scope ichan = pixels.map!(a => cast(coeff_t)a.i).array();
		scope qchan = pixels.map!(a => cast(coeff_t)a.q).array();

		haar2d(ychan, ImageWidth, ImageHeight);
		haar2d(ichan, ImageWidth, ImageHeight);
		haar2d(qchan, ImageWidth, ImageHeight);

		ret.dc = ImageDc(ychan[0], ichan[0], qchan[0]);

		scope ylargest = largestCoeffs(ychan[], NumSigCoeffs, 1);
		scope ilargest = largestCoeffs(ichan[], NumSigCoeffs, 1);
		scope qlargest = largestCoeffs(qchan[], NumSigCoeffs, 1);

		auto sig = ImageSig();
		// Add 1 to all of the indexes, because largestCoeff was passed the tail of
		// the channel, so all coeffs' indexes were shifted left.
		ylargest.map!(a => a.index)().copy(sig.y[]);
		ilargest.map!(a => a.index)().copy(sig.i[]);
		qlargest.map!(a => a.index)().copy(sig.q[]);
		ret.sig = sig;

		return ret;
	}
}

unittest {
	// Verify that the returned data isn't the initial struct state
	auto i = ImageSigDcRes.fromFile("test/white_line_10px_bmp.bmp");
	assert(i.res == ImageRes(10, 1));
	assert(i.dc != ImageDc.init);
	assert(i.sig != ImageSig.init);
}

/// For now, used when serializing image data to the disk
/// so an immutable user ID can be associated with it
struct ImageIdSigDcRes
{
	user_id_t user_id;
	ImageSig sig;
	ImageDc dc;
	ImageRes res;
}
