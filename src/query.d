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
import std.algorithm : sort, min, max, reverse;
import core.memory : GC;

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

	QueryResult[] perform(T)(BucketManager bucket_manager, T[] db_images) const
	if(is(typeof(T.init.dc) : ImageDc))
	{
		immutable num_results  = min(this.num_results, db_images.length);
		immutable in_image     = cast(immutable)*this.in_image;
		immutable ignore_color = this.ignore_color;
		immutable is_sketch    = this.is_sketch;

		immutable query_dc     = in_image.dc;

		scope score_t[] scores = new score_t[db_images.length];
		score_t total_bucket_weight = 0;

		if(ignore_color)
		{
			assert(false, "No B&W support... *yet*");
		}

		auto weights = Weights[is_sketch ? 1 : 0];
		immutable dc_weight_bin = 0;

		foreach(index, ref img; db_images)
		{
			immutable ImageDc dc = img.dc;

			score_t s = 0;
			foreach(chan; 0..NumColorChans)
			{
				score_t weight = cast(score_t)(weights[dc_weight_bin][chan]) / ScoreMax;

				//s += (((DScore)weights[sketch][0][c]) * abs(itr.avgl()[c] - q.avgl[c])) >> ScoreScale;
				//writeln("Diff in avgls: ", cast(score_t)(abs(dc.avgls[chan] - query_dc.avgls[chan])));
				//s += cast(int)(weights[dc_weight_bin][chan] * abs(dc.avgls[chan] - query_dc.avgls[chan]));
				s += cast(score_t)(weight * abs(dc.avgls[chan] - query_dc.avgls[chan]));
			}
			scores[index] = cast(score_t)s;
		}

		foreach(chan; 0..NumColorChans)
		{
			foreach(coeffi_t coeff_index; in_image.sig.sigs[chan])
			{
				// Grab the bucket for this (coefficient index, channel) pair
				Bucket* bucket = bucket_manager.bucketForCoeff(coeff_index, chan);
				auto weight = weights[WeightBins[abs(coeff_index)]][chan];

				total_bucket_weight += weight;

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

		ulong score_at = 0;

		auto best_matches = new ImageScorePair[num_results];
		scope(exit) { GC.free(best_matches.ptr); }

		// Fill up initial set of scores
		foreach(index, score; scores[0..num_results])
		{
			best_matches[index] = ImageScorePair(&db_images[index], score);
		}

		// Sort the scores
		auto heap_scores = best_matches.heapify!((a, b) {
			return a.score < b.score;
		});

		// Insert better matching scores from the rest of the scores array
		foreach(index, score; scores[num_results..$])
		{
			// The actual index of scores that we're at
			index = index + num_results;

			heap_scores.conditionalInsert(ImageScorePair(&(db_images[index]), score));
		}

		//score_scale = -1 * cast(score_t) (score_scale / ScoreMax);

		auto results = new QueryResult[num_results];
		foreach(index, match; best_matches)
		{
			//float sim = (cast(float)(-match.score) / cast(float)total_bucket_weight * 100.0);
			//float sim = cast(float)(match.score);

			// Yes, percentages can be negative for now. Perhaps clamp sim to [0, 100] regardless?
			float sim = cast(float)(-match.score) / cast(float)(total_bucket_weight) * 100.0;

			// Maybe?
			sim = max(0.0, sim);

			results[index] = QueryResult(match.image, sim);
		}

		sort!((a, b) => (a.similarity > b.similarity))(results);

		return results;
	}
}
