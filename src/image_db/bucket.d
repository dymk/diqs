module image_db.bucket;

/**
 * Bucket structure that manages an array of IdSets to accomidate fast
 * building of a database, and easy concurrent searching.
 */

import types :
  intern_id_t,
  coeffi_t;

import std.array : empty;
import std.algorithm : remove, countUntil, reduce, map, min, max;
import reserved_array : ReservedArray;

import delta_queue : DeltaQueue;

struct Bucket
{
	enum GUESS_SET_LEN =   5_000;
	enum MAX_SET_LEN   = 500_000;

	alias IdContainer = DeltaQueue!intern_id_t;

	size_t push(intern_id_t[] ids)
	{
		foreach(id; ids) {
			push(id);
		}

		return length();
	}
	size_t push(intern_id_t id)
	{
		IdContainer* dq;

		if(m_id_sets[].empty || !m_id_sets[][$-1].has_room(id)) {
			int container_len;

			if(this.size_hint <= 0)
			{
				// No size hint to go off of; make the new set a best guess length
				container_len = GUESS_SET_LEN;
			}
			else
			{
				// It's known images need to be appended, consume as much of
				// size_hint as MAX_SET_LEN will allow; but have a minimum size of
				// 1000 (arbitrary) so really small sets aren't created in case
				// size_hint was small.
				// Effectivly ensure that 1000 < container_len <
				//container_len = max(min(MAX_SET_LEN, size_hint), 1000);
				container_len = min(MAX_SET_LEN, size_hint);
				size_hint -= container_len;
			}

			m_id_sets.append(IdContainer(container_len));
		}

		dq = &m_id_sets[][$-1];
		return dq.push(id);
	}

	void sizeHint(int size)
	{
		this.size_hint = size;
	}

	bool remove(intern_id_t id)
	{
		foreach(ref dq; m_id_sets)
		{
			if(dq.remove(id))
			{
				return true;
			}
		}
		return false;
	}

	Range opSlice()
	{
		return Range(m_id_sets[]);
	}

	size_t length() {
		return reduce!((a, b) => a + b)(cast(size_t)0, m_id_sets[].map!(a => a.length));
	}

	struct Range
	{
		this(IdContainer[] sets)
		{
			this.sets = sets;
			if(this.sets.length)
			{
				current_set = this.sets[0][];
			}
		}

		bool empty() { return sets.length == 0 || current_set.empty; }
		intern_id_t front() {
			return current_set.front;
		}
		void popFront() {
			current_set.popFront();
			if(current_set.empty)
			{
				sets = sets[1..$];
				if(sets.length) {
					current_set = sets[0][];
				}
			}
		}

		private {
			IdContainer[] sets;
			IdContainer.Range current_set;
		}
	}

	const(IdContainer[]) sets() {
		return m_id_sets[];
	}

private:
	int size_hint;
	ReservedArray!IdContainer m_id_sets;
}

version(unittest) {
	import std.algorithm : equal;
}

unittest {
	Bucket b;
	b.push([1, 2, 3, 4, 5]);
	assert(b.length == 5);
}

unittest {
	Bucket b;
	b.push([1, 2, 3, 4, 5]);
	assert(equal(b[], [1, 2, 3, 4, 5]));
}

unittest {
	Bucket b;
	b.push([1, 2, 3, 4, 5]);
	assert(b.remove(1) == true);
	assert(b.length == 4);
}

unittest {
	Bucket b;
	assert(b.length == 0);
}

unittest {
	Bucket b;
	b.push(1);
	assert(equal(b[], [1]));
}

unittest {
	Bucket b;
	b.push([1, 2, 3]);
	assert(b.remove(4) == false);
	assert(b.remove(0) == false);
	assert(b.remove(1) == true);
	assert(b.remove(1) == false);
}

