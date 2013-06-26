module consts;
/*
 * Module Consts: Configuration constatants for DIQS.
 */

import std.algorithm : min, max;

/// Image constants
enum ImageHeight = 10;
enum ImageWidth  = 10;
enum ImageArea   = ImageHeight * ImageWidth;

/// Signature configuration
/// The number of coefficients that a signature represents
enum NumSigCoeffs = 40;

/// Weights for coefficient buckets
shared float[3][6][2] Weights = [
	// For scanned picture (sketch=0):
	[
	//  Y       I       Q
		[5.00f, 19.21f, 34.37f],
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

/// Maps coefficient location to a weight bucket
/// Initialized with a self executing lambda, a-la Javascript
shared byte[ImageArea] WeightBins = (() {
	byte[ImageArea] tmp;
	foreach(i; 0..ImageHeight) {
		foreach(j; 0..ImageWidth) {
			tmp[(i * ImageHeight) + j] = min(max(i, j), 5);
		}
	}
	return tmp;
})();

