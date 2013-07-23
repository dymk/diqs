module image_db.bucket;

/**
 * Bucket structure that holds a set of user_id_ts which represent
 * ImageDatum that have a given coefficient. Handles insertion,
 * existance checking, and removal of user_id_ts.
 */

import types :
  user_id_t,
  coeffi_t;

import std.algorithm :
  stdAlgoRemove = remove,
  sort,
  countUntil,
  SortedRange,
  SwapStrategy;
import std.range : assumeSorted;
import std.exception : enforce;


struct Bucket
{
	coeffi_t coeff;

	// Push an ID into the bucket
	size_t push(user_id_t id)
	{
		enforce(!has(id));
		m_mem_ids ~= id;
		m_sorted_mem_ids = sort(m_mem_ids);
		return length;
	}

	// Test if the bucket contains that ID
	bool has(user_id_t id)
	{
		return m_sorted_mem_ids.contains(id);
	}

	// Remove an ID from the bucket
	bool remove(user_id_t id)
	{
		// Get the position of the ID
		auto pos = m_sorted_mem_ids.countUntil(id);
		if(pos == -1)
			return false;
		m_mem_ids = m_mem_ids.stdAlgoRemove(pos);
		m_sorted_mem_ids = m_mem_ids.assumeSorted();
		return true;
	}

	auto ids() @property    { return m_sorted_mem_ids; }
	auto length() @property { return m_mem_ids.length; }

private:
	user_id_t[] m_mem_ids;
	SortedRange!(user_id_t[]) m_sorted_mem_ids;
}

version(unittest) {
	import std.algorithm : equal;
}

unittest {
	auto b = Bucket();
	b.push(1);
	b.push(2);
	assert(equal(b.ids, [1, 2]));
}

unittest {
	auto b = Bucket();
	b.push(1);
	b.remove(1);
	uint[] empty = [];
	assert(equal(b.ids, empty));
}

unittest {
	auto b = Bucket();
	foreach(i; 0..5)
		b.push(i);
	b.remove(1);
	assert(equal(b.ids, [0, 2, 3, 4]));
}
