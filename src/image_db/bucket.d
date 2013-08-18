module image_db.bucket;

/**
 * Bucket structure that manages an array of IdSets to accomidate fast
 * building of a database, and easy concurrent searching.
 */

import types :
  user_id_t,
  coeffi_t;

import std.array : empty;
import std.algorithm : remove, countUntil, reduce, map;
import reserved_array : ReservedArray;

version(UseIdSet) {
	pragma(msg, "Using IdSet version of Bucket");

	import image_db.id_set : IdSet;

	struct Bucket
	{
		// A smaller value here means more subsets will be created,
		// but also that relocation of the sets will be faster
		enum MAX_SET_LEN = 1_000_000;

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
			m_id_sets.append(IdSet(MAX_SET_LEN));
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
		ReservedArray!IdSet m_id_sets;
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
}
else
{
	pragma(msg, "Using DeltaQueue version of Bucket");

	import delta_queue : DeltaQueue;

	struct Bucket
	{
		enum MAX_SET_LEN = 100_000;

		size_t push(user_id_t[] ids)
		{
			foreach(id; ids) {
				push(id);
			}

			return length();
		}
		size_t push(user_id_t id)
		{
			DeltaQueue* dq;

			if(m_id_sets[].empty || !m_id_sets[][$-1].has_room(id))
			{
				m_id_sets.append(DeltaQueue(MAX_SET_LEN));
			}
			dq = &m_id_sets[][$-1];

			return dq.push(id);
		}

		bool remove(user_id_t id)
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
			this(DeltaQueue[] sets)
			{
				this.sets = sets;
				if(this.sets.length)
				{
					current_set = this.sets[0][];
				}
			}

			bool empty() { return sets.length == 0 || current_set.empty; }
			user_id_t front() {
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
				DeltaQueue[] sets;
				DeltaQueue.Range current_set;
			}
		}

		const(DeltaQueue[]) sets() {
			return m_id_sets[];
		}

	private:
		ReservedArray!DeltaQueue m_id_sets;
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
}

