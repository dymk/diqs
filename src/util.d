module util;

/**
 * Optimized versions of functions that can be found in the
 * standard library, or small ubiquitous functions that have no
 * other home.
 */

T min(T)(T a, T b)
{
	return (a < b) ? a : b;
}

T max(T)(T a, T b)
{
	return (a > b) ? a : b;
}
