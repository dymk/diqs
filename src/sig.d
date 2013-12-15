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

import std.exception : enforceEx;
import std.algorithm : map, copy, filter;
import std.range : array;
import std.string : format;
import std.stdio : writeln;
import std.file : exists;
import core.memory : GC;

struct CoeffIPair
{
	coeffi_t index;
	coeff_t  coeff = 0;

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

	static MagickWand resizeWand(MagickWand wand)
	{
		if(wand.imageWidth() != ImageWidth || wand.imageHeight() != ImageHeight)
		{
			wand.scaleImageEx(ImageWidth, ImageHeight);
		}
		return wand;
	}

	version(assert)
	{
		import std.algorithm : sort;

		bool sameAs(ImageSig other) const
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
	dc_t[NumColorChans] avgls;
	ref auto y() @property { return avgls[0]; }
	ref auto i() @property { return avgls[1]; }
	ref auto q() @property { return avgls[2]; }
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

struct ImageIdDcRes
{
	user_id_t user_id;
	ImageDc dc;
	ImageRes res;
}

struct ImageSigDcRes
{
	ImageSig sig;
	ImageDc dc;
	ImageRes res;

	static auto fromWand(MagickWand wand)
	{
		ImageSigDcRes ret;

		short
		  width = cast(res_t)wand.imageWidth(),
		  height = cast(res_t)wand.imageHeight();
		ret.res = ImageRes(width, height);

		ImageSig.resizeWand(wand);

		auto pixels = wand.exportImagePixelsFlatEx!YIQ();
		//scope(exit) { GC.free(pixels.ptr); }

		scope ychan = pixels.map!(a => cast(coeff_t)a.y).array();
		scope ichan = pixels.map!(a => cast(coeff_t)a.i).array();
		scope qchan = pixels.map!(a => cast(coeff_t)a.q).array();

		haar2d(ychan, ImageWidth, ImageHeight);
		haar2d(ichan, ImageWidth, ImageHeight);
		haar2d(qchan, ImageWidth, ImageHeight);

		ret.dc.y = ychan[0];
		ret.dc.i = ichan[0];
		ret.dc.q = qchan[0];

		scope ylargest = largestCoeffs(ychan[], NumSigCoeffs, 1);
		scope ilargest = largestCoeffs(ichan[], NumSigCoeffs, 1);
		scope qlargest = largestCoeffs(qchan[], NumSigCoeffs, 1);

		auto sig = ImageSig();

		// Add 1 to all of the indexes, because largestCoeff was passed the tail of
		// the channel, so all coeffs' indexes were shifted left.
		// If coeff is negative, make the index negative as well.
		ylargest.map!(a => a.coeff < 0 ? -a.index : a.index)().copy(sig.y[]);
		ilargest.map!(a => a.coeff < 0 ? -a.index : a.index)().copy(sig.i[]);
		qlargest.map!(a => a.coeff < 0 ? -a.index : a.index)().copy(sig.q[]);

		ret.sig = sig;

		version(assert) {
			foreach(sig_t s; ret.sig.sigs) {
				if(filter!(a => a == 0)(s[]).array().length != 0)
				{
					writeln(format("0 coeff found in sig: %s", s[]));
					writeln("First set from the chan: ", ychan[0..10]);
					writeln("DC: ", ret.dc);
					assert(false);
				}
			}
		}

		return ret;

	}

	static auto fromFile(string file)
	{
		auto wand = MagickWand.fromFile(file);
		scope(exit) { MagickWand.disposeWand(wand); }

		return ImageSigDcRes.fromWand(wand);
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

	static ImageIdSigDcRes fromSigDcRes(in ImageSigDcRes img, user_id_t user_id)
	{
		return ImageIdSigDcRes(user_id, img.sig, img.dc, img.res);
	}
}

version(unittest) {
	bool sameAs(ImageIdSigDcRes a, ImageIdSigDcRes b) {
		return (
			a.user_id == b.user_id &&
			     a.dc == b.dc &&
			    a.res == b.res &&
			a.sig.sameAs(b.sig));
	}
}

version(unittest)
{
	ImageSigDcRes*[string] alreadyLoaded;

	ImageIdSigDcRes imageFromFile(user_id_t id, string path)
	{
		auto i = imageFromFile(path);
		return ImageIdSigDcRes(id, i.sig, i.dc, i.res);
	}

	ImageSigDcRes imageFromFile(string path)
	{
		if(path !in alreadyLoaded)
		{
			writeln("Caching signature for image " ~ path);
			auto allocd = new ImageSigDcRes;
			auto reted = ImageSigDcRes.fromFile(path);

			allocd.sig = reted.sig;
			allocd.dc = reted.dc;
			allocd.res = reted.res;

			alreadyLoaded[path] = allocd;
		}

		auto i = alreadyLoaded[path];
		return ImageSigDcRes(i.sig, i.dc, i.res);
	}
}

unittest
{
	ImageSigDcRes data = ImageSigDcRes.fromFile("test/cat_a1.jpg");
	assert(data.res == ImageRes(650, 433));
	assert(data != ImageSigDcRes.init);
}
