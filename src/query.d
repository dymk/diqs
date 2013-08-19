/**
 * Structures and functions relating to image similarity
 * scoring.
 * and the
 */
module query;

import image_db.bucket_manager :
  BucketManager;
import image_db.bucket :
  Bucket;
import consts :
  Weights,
  WeightsBase,
  WeightBins;
import sig :
	ImageSigDcRes,
	ImageIdDcRes,
	ImageDcRes,
	ImageDc;
import types :
  score_t,
  coeffi_t;
import consts :
  NumColorChans,
  ScoreMax,
  ScoreScale;
import std.math : abs;

import std.stdio : writeln;
import std.container : heapify;
import std.algorithm : sort, min;

struct QueryResult
{
	ImageIdDcRes* image;
	float similarity;
}

struct QueryParams
{
	ImageSigDcRes* in_image;
	uint num_results = 10;
	bool ignore_color = false;
	bool is_sketch = false;

	auto perform(T)(BucketManager bucket_manager, T[] db_images) const
	if(is(typeof(T.init.dc) : ImageDc))
	{
		immutable num_results  = min(this.num_results, db_images.length);
		immutable in_image     = cast(immutable)*this.in_image;
		immutable ignore_color = this.ignore_color;
		immutable is_sketch    = this.is_sketch;

		immutable query_dc     = in_image.dc;

		scope score_t[] scores = new score_t[db_images.length];
		score_t score_scale = 0;

		if(ignore_color)
		{
			assert(false, "No B&W support... *yet*");
		}

		auto weights = WeightsBase[is_sketch ? 1 : 0];
		immutable dc_weight_bin = 0;

		foreach(index, ref img; db_images)
		{
			immutable ImageDc dc = img.dc;

			int s = 0;
			foreach(chan; 0..NumColorChans)
			{
				s += cast(int)(weights[dc_weight_bin][chan] * abs(dc.avgls[chan] - query_dc.avgls[chan]));
			}
			scores[index] = cast(score_t)s;
		}

		writeln("Scores after avgl calculation: ", scores);

		foreach(chan; 0..NumColorChans)
		{
			foreach(coeffi_t coeff_index; in_image.sig.sigs[chan])
			{
				// Grab the bucket for this (coefficient index, channel) pair
				Bucket* bucket = bucket_manager.bucketForCoeff(coeff_index, chan);
				auto weight = weights[WeightBins[abs(coeff_index)]][chan];
				score_scale -= weight;

				foreach(image_index; bucket.opSlice())
				{
					scores[image_index] -= weight;
				}
			}
		}

		struct ImageScorePair
		{
			ImageIdDcRes* image;
			score_t score;
		}

		// TODO: replace with some sort of memset
		scope best_matches = new ImageScorePair[num_results];
		foreach(ref bm; best_matches)
		{
			bm.score = score_t.max;
		}

		auto heap_scores = best_matches.heapify!((a, b) {
			return a.score < b.score;
		});

		// Fill up until the initial size is reached
		foreach(index, score; scores)
		{
			heap_scores.conditionalInsert(ImageScorePair(&(db_images[index]), score));
		}

		best_matches.sort!(function(a, b) {
			return a.score < b.score;
		});

		writeln("Scale is: ", score_scale);

		//writeln("Score max is ", ScoreMax);
		//score_scale = -1 * cast(score_t) (score_scale / ScoreMax);
		//writeln("Score scale is now: ", score_scale);


		auto results = new QueryResult[num_results];
		foreach(index, match; best_matches)
		{
			writeln("Adding image with score ", match.score);
			float sim = (cast(float)match.score / cast(float)score_scale * 100.0);
			results[index] = QueryResult(match.image, sim);
		}

		return results;
	}
}
