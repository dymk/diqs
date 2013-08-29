module consts;
/*
 * Module Consts: Configuration constatants for DIQS.
 */

import util : min, max;
import types :
  score_t;

import std.math : lrint;

/// Image constants
enum short ImageHeight   = 128;
enum short ImageWidth    = 128;
enum short ImageArea     = ImageHeight * ImageWidth;
enum ubyte NumColorChans = 3;

// The number of buckets held by the bucket manager per channel
enum NumBucketsPerChan = (ImageArea * 2) - 1;
enum NumBuckets = NumColorChans * NumBucketsPerChan;

/// Signature configuration
/// The number of coefficients that a signature represents
enum NumSigCoeffs = 40;

// Maximum score and score scaling values
enum score_t ScoreScale = 20;
enum score_t ScoreMax   = (1 << ScoreScale);

/// Weights for coefficient buckets
/// Access like Weights[is_sketch ? 1 : 0][weight_bin][color_channel]
static immutable shared float[3][6][2] WeightsBase = [
	// For scanned picture (sketch=0):
	[
	//  Y       I       Q
		[5.00f, 19.21f, 34.37f], // First set is the DC coeff weights
		[0.83f,  1.26f,  0.36f],
		[1.01f,  0.44f,  0.45f],
		[0.52f,  0.53f,  0.14f],
		[0.47f,  0.28f,  0.18f],
		[0.30f,  0.14f,  0.27f]
	],

	// For handdrawn/painted sketch (sketch=1):
	[
		[4.04f, 15.14f, 22.62f],
		[0.78f,  0.92f,  0.40f],
		[0.46f,  0.53f,  0.63f],
		[0.42f,  0.26f,  0.25f],
		[0.41f,  0.14f,  0.15f],
		[0.32f,  0.07f,  0.38f]
	]
];

static immutable shared score_t[3][6][2] Weights = (() {
	score_t[3][6][2] tmp;
	foreach(a, first; WeightsBase)
	{
		foreach(b, second; first)
		{
			foreach(c, value; second)
			{
				tmp[a][b][c] = cast(score_t)(value * ScoreMax);
			}
		}
	}
	return tmp;
})();

/// Maps coefficient location to a weight bucket
/// Initialized with a self executing lambda, a-la Javascript
shared ubyte[ImageArea] WeightBins = (() {
	ubyte[ImageArea] tmp;
	foreach(i; 0..ImageHeight) {
		foreach(j; 0..ImageWidth) {
			tmp[(i * ImageHeight) + j] = cast(ubyte) min(max(i, j), 5);
		}
	}
	return tmp;
})();

