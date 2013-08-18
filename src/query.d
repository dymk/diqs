/**
 * Structures and functions relating to image similarity
 * scoring.
 * and the
 */
module query;

import consts :
  Weights,
  WeightBins;
import sig :
	ImageSigDcRes,
	ImageDcRes;
import types :
  score_t;

struct QueryResult
{
	ImageDcRes* image;
	score_t score;
}

struct QueryParams
{
	ImageSigDcRes* in_image;
	uint num_results = 10;
	bool ignore_color = false;

	QueryResult[] perform(T)(QueryParams params, BucketManager bucket_manager, T[] db_images)
	if(
		is(T == ImageDcRes) ||
		is(T == ImageSigDcRes))
	{
		immutable num_results  = params.num_results;
		immutable in_image     = params.in_image;
		immutable ignore_color = params.ignore_color;
	}
}
