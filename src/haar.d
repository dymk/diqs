module haar;

import std.array;
import std.range;
import std.typecons;
import std.algorithm;
import std.traits;
import std.math;

float[][] haar2d(T)(const T[][] in_mat) @safe pure nothrow
if(is(T : float))
in
{
	assert(in_mat.length);
	assert(in_mat[0]);
	assert(in_mat[0].length);
}
body
{
	auto in_mat_rows = in_mat.length,
	     in_mat_cols = in_mat.front.length;
	auto out_mat     = new float[][in_mat_rows];

	// Verify the matrix isn't jagged
	foreach(ref row; in_mat) {
		assert(row.length == in_mat_cols);
	}

	// Perform on each row
	foreach(i, ref row; in_mat) {
		out_mat[i] = haar1d(row);
	}

	// And now on each column
	scope temp_row = new float[in_mat_rows];
	foreach(x; 0..in_mat_cols) {
		foreach(y; 0..in_mat_rows) {
			temp_row[y] = out_mat[y][x];
		}

		auto haar_row = haar1d(temp_row);

		foreach(y; 0..in_mat_rows) {
			out_mat[y][x] = haar_row[y];
		}
	}

	return out_mat;
}

unittest {
	auto in_vec = [
		[5.0, 6.0, 1.0, 2.0],
		[4.0, 2.0, 5.0, 5.0],
		[3.0, 1.0, 7.0, 1.0],
		[6.0, 3.0, 5.0, 1.0]
	 ];
	auto expected_vec = [
	  [14.25f,        0.75f,        2.12132034f,  3.18198052f],
	  [ 0.75f,        1.25f,       -1.41421356f, -3.8890873f],
	  [-0.70710678f,  4.24264069f, -1.5f,        -0.5f],
	  [-1.06066017f, -2.47487373f, -0.5f,         1.0f]
	];

	auto out_vec = haar2d(in_vec);
	foreach(y, row; out_vec) {
		foreach(x, value; row) {
			assert(value.approxEqual(expected_vec[y][x]));
		}
	}
}

float[] haar1d(T)(const T[] in_vec) @safe pure nothrow
if(is(T : float))
{
	auto in_vec_len      = in_vec.length;
	auto  out_vec        = new float[in_vec_len];
	scope temp_vec       = new float[in_vec_len];
	foreach(i, val; in_vec) {
		out_vec[i] = val;
	}

	// How far to itterate over the input vector
	auto  temp_vec_bound = in_vec_len;

	while(temp_vec_bound > 1) {
		temp_vec_bound /= 2;
		const tvb = temp_vec_bound;

		foreach(i; 0..temp_vec_bound) {
			const i2 = i*2;
			temp_vec[i]    =(out_vec[i2] + out_vec[i2+1]) / SQRT2;
			temp_vec[i+tvb]=(out_vec[i2] - out_vec[i2+1]) / SQRT2;
		}

		if(tvb > 1) {
			// Going to itterate over again; copy
			// relevant changes into input vector
			foreach(i; 0..tvb*2) {
				out_vec[i] = temp_vec[i];
			}
		}
	}

	out_vec[] = temp_vec[];
	return out_vec;
}

unittest {
	auto out_vec = haar1d([4.0, 2.0, 5.0, 5.0]);
	assert(out_vec[0].approxEqual(8.0));
	assert(out_vec[1].approxEqual(-2.0));
	assert(out_vec[2].approxEqual((2.0/SQRT2)));
	assert(out_vec[3].approxEqual(0.0));
}
