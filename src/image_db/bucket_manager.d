module image_db.bucket_manager;

/**
 * Manages a set of buckets for the entire range of possible image coefficients
 */

import image_db.bucket;
import types :
  coeffi_t,
  chan_t,
  intern_id_t;
import sig : ImageSig;
import consts :
  ImageArea,
  NumBuckets,
  NumSigCoeffs,
  NumColorChans,
  NumBucketsPerChan;

import std.exception : enforce;
import std.conv : to;

// A wrapper struct for easy passing and manipulation of bucket sizes.
struct BucketSizes
 {
	uint[NumBuckets] sizes;

	uint[] Y() { return cast(uint[]) forChan(0); }
	uint[] I() { return cast(uint[]) forChan(1); }
	uint[] Q() { return cast(uint[]) forChan(2); }

	const(uint[]) forChan(ubyte chan) const
	{
		enforce(chan < NumColorChans);
		return sizes[(chan * NumBucketsPerChan) .. ((chan+1) * NumBucketsPerChan)];
	}
}

unittest
{
	BucketSizes bs;
	bs.Y()[0] = 12;
	assert(bs.Y().length == NumBucketsPerChan);
	assert(bs.sizes[0] == 12);
}

final class BucketManager
{
	this()
	{
		foreach(ref chan; m_buckets)
		{
			chan = new Bucket[](NumBucketsPerChan);
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
		this._length++;
	}

	// Simple wrapper function to move 'from' to 'to'
	void moveId(const intern_id_t from, const intern_id_t to)
	{
		auto rm_sig = removeId(from);
		addSig(to, rm_sig);
	}

	// Removes an ID from the bucket set, and
	// returns the resulting signature that would
	// have been used to insert it in the first place.
	ImageSig removeId(intern_id_t intern_id)
	{
		ImageSig ret;

		// Itterate over each channel of the image
		foreach(chan; 0..NumColorChans)
		{
			// Store the buckets that the image's ID was in
			int found = 0;
			foreach(short i, ref bucket; m_buckets[chan])
			{
				if(bucket.remove(intern_id))
				{
					ret.sigs[chan][found] = coeffForBucketIndex(i);
					found++;
				}
			}

			enforce(found == NumSigCoeffs,
				"Image with internal ID " ~
				to!string(intern_id) ~
				" didn't have enough coeffs (found: " ~ to!string(found) ~ ")");
		}
		this._length--;
		return ret;
	}

	ref Bucket bucketForCoeff(coeffi_t coeff, chan_t chan)
	{
		return m_buckets[chan][bucketIndexForCoeff(coeff)];
	}

	ref const auto buckets() @property
	{
		return m_buckets;
	}

	auto bucketSizeHint(const(BucketSizes*) bucket_sizes) {
		foreach(ubyte chan; 0..NumColorChans)
		{
			auto chan_sizes = bucket_sizes.forChan(chan);
			foreach(ushort index, uint bucket_size; chan_sizes)
			{
				auto bucket = bucketForCoeff(coeffForBucketIndex(index), chan);
				bucket.sizeHint(bucket_size);
			}
		}
	}

	static ushort bucketIndexForCoeff(coeffi_t coeff)
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
	static coeffi_t coeffForBucketIndex(ushort index)
	{
		if(index >= ImageArea)
			index++;
		index -= ImageArea;
		return index;
	}

	Bucket* bucketForCoeff(coeffi_t coeff, int channel)
	{
		auto index_at = this.bucketIndexForCoeff(coeff);
		return &this.m_buckets[channel][index_at];
	}

	auto length() { return _length; }

private:
	size_t _length;
	Bucket[][NumColorChans] m_buckets;
}


version(unittest)
{
	import sig : imageFromFile;

	ImageSig getSig()
	{
		return imageFromFile("test/cat_a1.jpg").sig;
	}
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

unittest {
	auto f = new BucketManager();
	assert(f.length == 0);
}

unittest {
	auto f = new BucketManager();
	f.addSig(1, getSig());
	assert(f.length == 1);
}

unittest {
	auto f = new BucketManager();
	f.addSig(1, getSig());
	f.removeId(1);
	assert(f.length == 0);
}

unittest {
	auto f = new BucketManager();
	f.addSig(1, getSig());
	auto ret = f.removeId(1);
	assert(ret.sameAs(getSig()));
}

unittest {
	auto f = new BucketManager();
	f.addSig(1, getSig());
	f.moveId(1, 2);
	auto ret = f.removeId(2);
	assert(ret.sameAs(getSig()));
}

unittest {
	auto f = new BucketManager();
	auto b1 = f.bucketForCoeff(10, 0);
	auto b2 = f.bucketForCoeff(-10, 0);
	b1.push(0);
	assert(b1.length == 1);
	assert(b2.length == 0);

	b2.push(2);
	assert(b1.length == 1);
	assert(b2.length == 1);
}
