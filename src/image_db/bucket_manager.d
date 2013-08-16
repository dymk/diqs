module image_db.bucket_manager;

/**
 * Manages a set of buckets for the entire range of possible image coefficients
 */

import image_db.bucket;
import types : coeffi_t, chan_t, intern_id_t;
import sig : ImageSig;
import consts: NumColorChans, ImageArea;

final class BucketManager
{
	this() {
		auto chan_length = (ImageArea*2)-1;
		foreach(ref chan; m_buckets)
		{
			chan = new Bucket[chan_length];
		}
	}

	void addSig(intern_id_t id, in ImageSig sig)
	{
		// populate the relevant buckets with that image's data
		foreach(ubyte chan; 0..sig.sigs.length)
		{
			foreach(coeffi_t coeff; sig.sigs[chan])
			{
				bucketForCoeff(coeff, chan).push(id);
			}
		}
	}

	ref Bucket bucketForCoeff(coeffi_t coeff, chan_t chan)
	{
		return m_buckets[chan][bucketIndexForCoeff(coeff)];
	}

	ref const auto buckets() @property
	{
		return m_buckets;
	}

	static short bucketIndexForCoeff(coeffi_t coeff)
	{
		assert(coeff != 0, "Coeff at 0 is a DC component; not a sig coeff");
		// Because there is no 0 bucket, shift
		// all bucekts > 0 down by 1
		if(coeff > 0)
			coeff--;
		coeff += ImageArea; // Eg bucket -16384 => 0
		return coeff;
	}

	/// Inverse of bucketIndexForCoeff
	/// Convert a bucket's index to a coefficient
	/// EG 0 => -16384
	static coeffi_t coeffForBucketIndex(short index)
	{
		if(index >= ImageArea)
			index++;
		index -= ImageArea;
		return index;
	}

private:
	Bucket[][NumColorChans] m_buckets;
}

unittest {
	auto f = new BucketManager();
	assert(f.buckets().length);
}

unittest {
	auto f = new BucketManager();
	assert(f.bucketIndexForCoeff(-16384) == 0);
	assert(f.bucketIndexForCoeff(-16383) == 1);

	assert(f.bucketIndexForCoeff(-1)     == 16383);
	assert(f.bucketIndexForCoeff(1)      == 16384);
	assert(f.bucketIndexForCoeff(16384)  == 32767);
}

unittest {
	auto f = new BucketManager();
	assert(f.coeffForBucketIndex(0)      == -16384);
	assert(f.coeffForBucketIndex(16383)  == -1);
	assert(f.coeffForBucketIndex(16384)  == 1);
	assert(f.coeffForBucketIndex(32767)  == 16384);
}
