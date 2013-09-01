module haar;

import std.array : front;
import std.math : SQRT2, approxEqual;
import std.exception : enforce;
import std.parallelism : taskPool;
import std.range : iota;

import core.memory : GC;

/* Convert an array of pixels to a X by Y matrix of pixels */
C[] vecToMat(C)(C chan, size_t width, size_t height) @safe pure nothrow
{
	assert(width * height == chan.length);
	auto ret = new C[height];
	foreach(rowNum; 0..height)
	{
		ret[rowNum] = chan[rowNum * width .. (rowNum+1) * width];
	}
	return ret;
}

unittest {
	assert([1, 2, 3, 4].vecToMat(2, 2) == [[1, 2], [3, 4]]);
}

void haar2d(T)(T[] in_vec, size_t width, size_t height)
if(is(T : float))
{
	scope mat = vecToMat(in_vec, width, height);
	haar2d(mat);
}

void haar2d(T)(T[][] in_mat)
if(is(T : float))
{
	auto in_mat_rows = in_mat.length,
	     in_mat_cols = in_mat.front.length;

	// Verify the matrix isn't jagged
	foreach(ref row; in_mat) {
		assert(row.length == in_mat_cols);
	}

	// Perform on each row
	foreach(i, ref row; taskPool.parallel(in_mat)) {
	//foreach(i, ref row; in_mat) {
		haar1d(row);
	}

	// And now on each column
	foreach(x; taskPool.parallel(iota(in_mat_cols))) {
		auto temp_row = new float[in_mat_rows];
		scope(exit) { GC.free(temp_row.ptr); }

	//foreach(x; iota(in_mat_cols)) {
		foreach(y; 0..in_mat_rows) {
			temp_row[y] = in_mat[y][x];
		}

		haar1d(temp_row);

		foreach(y; 0..in_mat_rows) {
			in_mat[y][x] = temp_row[y];
		}
	}
}

/* Test haar2d on a matrix */
unittest {
	auto in_mat = [
		[5.0f, 6.0f, 1.0f, 2.0f],
		[4.0f, 2.0f, 5.0f, 5.0f],
		[3.0f, 1.0f, 7.0f, 1.0f],
		[6.0f, 3.0f, 5.0f, 1.0f]
	 ].dup;
	auto expected_mat = [
	  [14.25f,        0.75f,        2.12132034f,  3.18198052f],
	  [ 0.75f,        1.25f,       -1.41421356f, -3.8890873f],
	  [-0.70710678f,  4.24264069f, -1.5f,        -0.5f],
	  [-1.06066017f, -2.47487373f, -0.5f,         1.0f]
	];

	haar2d(in_mat);
	foreach(y, row; in_mat) {
		foreach(x, value; row) {
			assert(value.approxEqual(expected_mat[y][x]));
		}
	}
}

/* Test haar2d on a vector with explicit dimentions */
unittest {
	auto in_vec = [
		5.0f, 6.0f, 1.0f, 2.0f,
		4.0f, 2.0f, 5.0f, 5.0f,
		3.0f, 1.0f, 7.0f, 1.0f,
		6.0f, 3.0f, 5.0f, 1.0f
	 ].dup;
	auto expected_vec = [
	  14.25f,        0.75f,        2.12132034f,  3.18198052f,
	   0.75f,        1.25f,       -1.41421356f, -3.8890873f,
	  -0.70710678f,  4.24264069f, -1.5f,        -0.5f,
	  -1.06066017f, -2.47487373f, -0.5f,         1.0f
	];

	haar2d(in_vec, 4, 4);
	foreach(i, value; in_vec) {
		assert(value.approxEqual(expected_vec[i]));
	}
}

void haar1d(T)(T[] in_vec) @safe pure nothrow
if(is(T : float))
{
	auto in_vec_len = in_vec.length;
	scope temp_vec  = new float[in_vec_len];

	// How far to itterate over the input vector
	auto  temp_vec_bound = in_vec_len;

	while(temp_vec_bound > 1) {
		temp_vec_bound /= 2;
		const tvb = temp_vec_bound;

		foreach(i; 0..temp_vec_bound) {
			const i2 = i*2;
			temp_vec[i]    =(in_vec[i2] + in_vec[i2+1]) / SQRT2;
			temp_vec[i+tvb]=(in_vec[i2] - in_vec[i2+1]) / SQRT2;
		}

		if(tvb > 1) {
			// Going to itterate over again; copy
			// relevant changes into input vector
			foreach(i; 0..tvb*2) {
				in_vec[i] = temp_vec[i];
			}
		}
	}

	in_vec[] = temp_vec[];
}

unittest {
	auto out_vec = [4.0f, 2.0f, 5.0f, 5.0f].dup;
	haar1d(out_vec);
	assert(out_vec[0].approxEqual(8.0));
	assert(out_vec[1].approxEqual(-2.0));
	assert(out_vec[2].approxEqual((2.0/SQRT2)));
	assert(out_vec[3].approxEqual(0.0));
}
