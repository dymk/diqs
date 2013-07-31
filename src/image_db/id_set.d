module image_db.id_set;

/**
 * IdSet structure holds a set of unique user_id_ts, and
 * tracks the upper and lower bounds of the contained set.
 */

//import types :
//  user_id_t;
alias user_id_t = size_t;
import reserved_array : ReservedArray;

import std.algorithm :
  stdAlgoRemove = remove,
  sort,
  countUntil,
  SortedRange;
import std.range : assumeSorted;
import std.array : empty, insertInPlace;


alias IdArray = ReservedArray!user_id_t;

struct IdSet
{
	// This bucket holds IDs from [lb, ub)
	user_id_t lower_bound;
	user_id_t upper_bound;

	this(size_t size_hint)
	{
		m_mem_ids = IdArray(size_hint);
	}

	// Push an ID into the tail of the set
	size_t push(in user_id_t id)
	in
	{
		assert(canPush(id));
	}
	body
	{
		m_mem_ids ~= id;
		refresh_bounds();
		return length;
	}

	// Last resort method that inserts the ID into the middle of the set
	size_t insert(in user_id_t id)
	in
	{
		assert(!has(id));
	}
	body
	{
		auto index = indexToInsertAt(m_mem_ids.data, id);
		m_mem_ids.insertInPlace(index, id);
		return index;
	}

	// Test if the bucket contains that ID
	bool has(user_id_t id)
	{
		if(id < lower_bound || id >= upper_bound)
			return false;
		return sortedIds.contains(id);
	}

	// Remove an ID from the bucket
	bool remove(user_id_t id)
	{
		// Get the position of the ID
		// TODO: Use binary search; not O(n) countUntil
		auto pos = m_mem_ids.data.countUntil(id);
		if(pos == -1)
			return false;

		m_mem_ids.remove(pos);

		refresh_bounds();

		return true;
	}

	auto range()  const @property { return upper_bound - lower_bound; }
	auto ids()          @property { return sortedIds; }
	auto length()       @property { return m_mem_ids.length; }
	auto empty()        @property { return m_mem_ids.empty; }
	auto sortedIds()    @property { return m_mem_ids.data.assumeSorted(); }

private:
	void refresh_bounds()
	{
		if(!sortedIds.empty)
		{
			lower_bound = sortedIds[0];
			upper_bound = sortedIds[$-1]+1;
		}
		else
		{
			lower_bound = upper_bound = 0;
		}
	}

	// Should only be used in non-release code
	bool canPush(in user_id_t id)
	{
		return !has(id) && (id >= upper_bound);
	}

	IdArray m_mem_ids;
}

// Performs an itterative binary search to find the location an ID should be inserted at
// to keep 'ids' sorted.
private auto indexToInsertAt(T)(in T[] haystack, in T needle)
{
	size_t max = haystack.length, min, mid;

	// continually narrow search until just one element remains
	while (min < max)
	{
		mid = (min+max)/2;

		assert(mid < max);

		// reduce the search
		if (haystack[mid] < needle)
			min = mid + 1;
		else
			max = mid;
	}
	if((mid + max) % 2 == 0) {
		return mid;
	} else {
		// Midpoint was rounded down; compensate
		return mid+1;
	}
}

unittest {
	assert([1, 2, 4].indexToInsertAt(3) == 2);

	int[] e = [];
	assert(indexToInsertAt(e,      0) == 0);
	assert(indexToInsertAt(e,      1) == 0);
	assert(indexToInsertAt([1],    2) == 1);
	assert(indexToInsertAt([1, 3], 2) == 1);
	assert(indexToInsertAt([1, 2], 3) == 2);

	assert(indexToInsertAt([1, 2, 4],    3) == 2);
	assert(indexToInsertAt([1, 2, 4, 5], 3) == 2);

	assert(indexToInsertAt([1, 2, 3], 0) == 0);
	assert(indexToInsertAt([2, 3, 4], 1) == 0);
}

version(unittest) {
	import std.algorithm : equal;
}

unittest {
	auto b = IdSet();
	b.push(1);
	b.push(2);
	assert(equal(b.ids, [1, 2]));
}

unittest {
	auto b = IdSet();
	b.push(1);
	b.remove(1);
	uint[] empty = [];
	assert(equal(b.ids, empty));
}

unittest {
	auto b = IdSet();
	b.insert(1);
	assert(equal(b.ids, [1]));
}

unittest {
	auto b = IdSet();
	b.push(1);
	b.push(3);
	b.insert(2);
	assert(equal(b.ids, [1, 2, 3]));
	assert(b.range == 3);
}

unittest {
	auto b = IdSet();
	foreach(i; 0..5)
		b.push(i);
	b.remove(1);
	assert(equal(b.ids, [0, 2, 3, 4]));
	b.remove(3);
	assert(equal(b.ids, [0, 2, 4]));
}

unittest {
	auto b = IdSet();
	assert(b.range == 0);
}

unittest {
	auto b = IdSet();
	foreach(i; 0..5)
		b.push(i);
	assert(b.range == 5); // [0, 1, 2, 3, 4]

	b.remove(3); // [0, 1, 2, 4]
	assert(b.range == 5);

	b.remove(4); // [0, 1, 2]
	assert(b.range == 3);

	b.remove(0); // [1, 2]
	assert(b.range == 2);
}

unittest {
	auto b = IdSet();
	assert(b.lower_bound == 0);
	assert(b.upper_bound == 0);

	b.push(1);
	assert(b.lower_bound == 1);
	assert(b.upper_bound == 2);

	b.remove(1);
	assert(b.lower_bound == 0);
	assert(b.upper_bound == 0);
}

unittest {
	auto b = IdSet();
	b.push(1);
	b.push(5);
	b.push(100);
	assert(b.lower_bound == 1);
	assert(b.upper_bound == 101);

	b.remove(100);
	assert(b.lower_bound == 1);
	assert(b.upper_bound == 6);
}
