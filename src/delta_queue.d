module delta_queue;

/**
 * Based off of Piespy's delta_queue, in IQDB
 */

import core.memory : GC;
debug {
	import std.stdio : stderr, writeln;
}

struct DeltaQueue(run_start_t)
{
	alias run_start_t_arr = ubyte[run_start_t.sizeof];

	this(size_t amt) {
		reserve(amt);
	}

	// Reserves a bit more than what amt should be able to hold,
	// as a few values that will trigger a marker byte are bound
	// to be passed in at some point or another. Reserves enough
	// space for 16 marker bytes.
	auto reserve(size_t amt) {
		return data.reserve(amt + (16*(run_start_t.sizeof+1)));
	}

	// Reserves an exact number of bytes. Used mostly internally
	// in the remove() method.
	auto reserve_exact(size_t amt) {
		return data.reserve(amt);
	}

	// Returns true or false if there is enough internal room to
	// push `num` to the internal data store.
	bool has_room(run_start_t num) {
		// Can the number be stored as a delta value, or as a new run?
		auto delta_can_fit = num > last_value && (num - last_value <= ubyte.max);
		auto required_bytes  = delta_can_fit ? ubyte.sizeof : run_start_t.sizeof;
		return data.capacity > (data.length + required_bytes);
	}

	// Pessimistic has_room(). Assumes that the next number pushed
	// will start a new run.
	bool has_room() {
		return data.capacity > (data.length + run_start_t.sizeof);
	}

	// Pushes a value onto the delta queue.
	size_t push(run_start_t push_value) {

		version(DebugDeltaQueue)
		{
			if(data.length >= data.capacity || !has_room(push_value)) {
				stderr.writeln("Warning: Will need to expand size of DeltaQueue (current length: ", data.length, ")");
			}
		}

		auto oldlen = data.length;
		if(data.length == 0)
		{
			data.length += run_start_t_arr.sizeof;
			data[0..run_start_t_arr.sizeof] = (*(cast(run_start_t_arr*) (&push_value)))[0..run_start_t_arr.sizeof];
		}
		else if(last_value >= push_value || (last_value + ubyte.max) < push_value)
		{
			data.length += 1 + run_start_t.sizeof;
			data[oldlen] = 0;
			data[oldlen+1 .. oldlen+run_start_t_arr.sizeof+1] = (*(cast(run_start_t_arr*)(&push_value)))[0..run_start_t_arr.sizeof];
		}
		else
		{
			data.length += 1;
			ubyte delta = cast(ubyte)(push_value - last_value);
			data[oldlen] = delta;
		}
		last_value = push_value;
		_length++;
		return _length;
	}

	// Removes all instances of rm_value from the delta_queue.
	// Terribly inefficient, but easy to reason about. Don't
	// call it in tight loops.
	// TODO: Make more efficient. Dunno how.
	bool remove(run_start_t rm_value)
	{
		// A nieve implementation that removes by totally rebuilding the
		// data[] array, skipping matching rm_values. It shouldn't
		// impact run speed by too much, because delta_queues are typically
		// only a few thousand elements long.

		// Basic speed hack to not allocate oodles of memory and then not
		// remove any values.
		if(!this.has(rm_value))
		{
			return false;
		}

		bool removed = false;
		DeltaQueue d;
		d.reserve_exact(this.length);

		foreach(i; this[]) {
			if(i == rm_value)
			{
				removed = true;
			}
			else
			{
				d.push(i);
			}
		}

		// Not exactly safe, so don't retain references to
		// ranges returned by delta_queues longer than you
		// really need to.
		GC.free(data.ptr);
		this.data = d.data;
		this._length = d.length;

		return removed;
	}

	// Used to slightly optimize remove()
	bool has(run_start_t value)
	{
		foreach(i; this[]) {
			if(i == value) {
				return true;
			}
		}
		return false;
	}

	// Returs the associated Range for a delta_queue.
	Range opSlice() {
		return Range(this.data, this.length);
	}

	auto length()   @property { return this._length; }

	struct Range {
		this(ubyte[] data, size_t length)
		{
			this.data = data;
			this._length = length;
			if(_length) {
				current_value = *(cast(run_start_t*) data.ptr);
				data_pos += run_start_t.sizeof;
			}
		}

		run_start_t front() {
			return current_value;
		}

		void popFront() {
			if(data_pos >= data.length) {
				data_pos++;
				return;
			}

			if(data[data_pos] == 0)
			{
				 //We've hit a marker zero; read the next run_start_t
				data_pos++;
				//current_value = *cast(run_start_t*)(data[data_pos..data_pos+run_start_t.sizeof].ptr);
				current_value = *(cast(run_start_t*)(&data[data_pos]));
				data_pos += run_start_t.sizeof;
			} else {
				// Normal delta value
				current_value += data[data_pos];
				data_pos++;
			}
		}

		auto length()   @property { return this._length; }
		bool empty()    @property { return data_pos > data.length || data.length == 0; }

		private {
			ubyte[] data;
			size_t _length;
			size_t data_pos;
			run_start_t current_value;
		}
	}

	ubyte[] data;
	private {
		size_t _length;
		run_start_t last_value;
	}
}

version(unittest) {
	import std.algorithm : equal;
	import std.range : iota, repeat;
	import std.typecons : TypeTuple;
	size_t[] empty_arr = [];

	alias TestTypes = TypeTuple!(int, uint, size_t, ulong, long, ushort, short);
}

unittest {
	foreach(Type; TestTypes)
	{

		DeltaQueue!Type d;
		d.push(2);
		d.push(2);
		d.push(3);
		d.push(5);
		assert(equal(d[], [2, 2, 3, 5]));
	}
}

unittest {
	foreach(Type; TestTypes)
	{

		DeltaQueue!Type d;
		foreach(i; iota(100)) {
			d.push(cast(Type)i);
		}
		assert(equal(d[], iota(100)));
	}
}

unittest {
	foreach(Type; TestTypes)
	{

		DeltaQueue!Type d;
		foreach(_; 0..100) {
			d.push(0);
		}
		assert(equal(d[], repeat(0)[0..100]));
	}
}

unittest {
	foreach(Type; TestTypes)
	{

		DeltaQueue!Type d;
		d.push(100);
		d.push(1);
		d.push(25);
		d.push(0);
		d.push(10000);
		assert(equal(d[], [100, 1, 25, 0, 10000]));
	}
}

unittest {
	foreach(Type; TestTypes)
	{

		DeltaQueue!Type d;
		assert(equal(d[], empty_arr));
	}
}

unittest {
	foreach(Type; TestTypes)
	{

		DeltaQueue!Type d;
		d.push(1);
		d.push(2);
		d.push(3);
		assert(d.length == 3);

		d.remove(2);
		assert(d.length == 2);
	}
}

unittest {
	foreach(Type; TestTypes)
	{

		DeltaQueue!Type d;
		d.push(1);
		d.push(2);
		d.push(3);

		d.remove(2);
		assert(equal(d[], [1, 3]));
	}
}

unittest {
	foreach(Type; TestTypes)
	{

		DeltaQueue!Type d;
		d.push(1);
		d.remove(1);
		auto slice = d[];

		assert(equal(d[], empty_arr));
	}
}

unittest {
	foreach(Type; TestTypes)
	{

		DeltaQueue!Type d;
		d.push(1);
		assert(d.remove(1) == true);
	}
}

unittest {
	foreach(Type; TestTypes)
	{

		DeltaQueue!Type d;
		assert(d.remove(1) == false);
	}
}
