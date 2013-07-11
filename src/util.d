module util;

/**
 * Optimized versions of functions that can be found in the
 * standard library, or small ubiquitous functions that have no
 * other home.
 */

import types : coeff_t;
import sig : CoeffIPair;
import std.range : isInputRange, array;
import std.algorithm : map, sort;

T min(T)(T a, T b)
{
	return (a < b) ? a : b;
}

T max(T)(T a, T b)
{
	return (a > b) ? a : b;
}

CoeffIPair[] largestCoeffs(C)(C[] coeffs, int n)
if(is(C : coeff_t))
{
	// Start at coeffs == 1 because the 0 coeff is a DC componenet, and
	// not used in the signature
	short i = 1;
	scope coeff_set = coeffs[i..$].map!(a => CoeffIPair(i++, a))().array();
	sort!("std.math.abs(a.coeff) > std.math.abs(b.coeff)")(coeff_set);
	return coeff_set[0..n].array(); //.array because coeff_set is scope
}

unittest {
	auto coeffs = [1.0, 2.0, 5.0, 3.0];
	assert(coeffs.largestCoeffs(2) ==
		[CoeffIPair(2, 5.0), CoeffIPair(3, 3.0)]);
	assert(coeffs.largestCoeffs(3) ==
		[CoeffIPair(2, 5.0), CoeffIPair(3, 3.0), CoeffIPair(1, 2.0)]);
	assert(coeffs.largestCoeffs(0) ==
		[]);
}

unittest {
	auto coeffs = [1.0, -2.0, -6.0, 3.0];
	assert(coeffs.largestCoeffs(2) ==
		[CoeffIPair(2, -6.0), CoeffIPair(3, 3.0)]);
}
