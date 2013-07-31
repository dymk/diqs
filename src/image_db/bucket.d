module image_db.bucket;

/**
 * Bucket structure that manages an array of IdSets to accomidate fast
 * building of a database, and easy concurrent searching.
 */

import types :
  user_id_t,
  coeffi_t;
import image_db.id_set : IdSet;

import std.array : empty, Appender;
import std.algorithm : remove, countUntil;

struct Bucket
{
	// A smaller value here means more subsets will be created,
	// but also that relocation of the sets will be faster
	enum MAX_SET_LEN = 10_000;

	immutable coeffi_t coeff;

	size_t push(in user_id_t id)
	{
		// First, try appending to the tail of an existing set
		// to avoid an expensive insert operation
		foreach(i, ref set; m_insertable_id_sets)
		{
			if(set.upper_bound <= id && canAddTo(set))
			{
				typeof(return) ret = set.push(id);
				recheckIsInsertable(set);
				return ret;
			}
		}

		// No luck, find the smallest set and insert into that
		// TODO: Perhaps find the smallest with std.algorithm.reduce?
		IdSet* shortest_set = null;
		foreach(i, ref set; m_insertable_id_sets)
		{
			if(shortest_set is null)
			{
				shortest_set = set;
			}
			else
			{
				shortest_set = shortest_set.length < set.length ? shortest_set : set;
			}
		}
		if(shortest_set !is null && shortest_set.length < MAX_SET_LEN)
		{
			typeof(return) ret = shortest_set.insert(id);
			recheckIsInsertable(shortest_set);
			return ret;
		}

		// No sets will suffice; just build a new one
		m_id_sets.put(IdSet(MAX_SET_LEN));
		IdSet* set = &(m_id_sets.data()[$-1]);
		auto ret = set.push(id);

		m_insertable_id_sets ~= set;

		return ret;
	}

	auto has(in user_id_t id)
	{
		foreach(ref set; m_id_sets.data())
		{
			if(set.has(id))
				return true;
		}
		return false;
	}

	auto sets() @property { return m_id_sets; }

private:
	// All of the ID sets that this bucket owns
	Appender!(IdSet[]) m_id_sets;
	// Array of sets under MAX_SET_LEN
	IdSet*[]           m_insertable_id_sets;

	// Can s have an ID inserted/pushed onto it?
	static bool canAddTo(IdSet* s)
	{
		return s.length < MAX_SET_LEN;
	}

	// Rechecs if s is still insertable, and if it's not,
	// remove it from m_insertable_id_sets
	bool recheckIsInsertable(IdSet* s)
	{
		if(canAddTo(s))
			return false;
		foreach(i, os; m_insertable_id_sets)
		{
			if(os is s)
			{
				m_insertable_id_sets.remove(i);
				return true;
			}
		}
		return false;
	}

}

unittest {
	auto b = Bucket();
	assert(b.sets.data().length == 0);
}

unittest {
	auto b = Bucket();
	b.push(1);
	assert(b.sets.data().length == 1);
}

unittest {
	auto b = Bucket();
	b.push(1);
	assert(b.has(1));
}

unittest {
	auto b = Bucket();
	foreach(i; 0..Bucket.MAX_SET_LEN)
		b.push(i);
	assert(b.sets.data().length == 1);

	b.push(Bucket.MAX_SET_LEN);
	assert(b.sets.data().length == 2);
}
