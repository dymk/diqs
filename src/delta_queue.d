module delta_queue;

/**
 * Based off of Piespy's delta_queue, in IQDB
 */

debug {
	import std.stdio : stderr, writeln;
}

struct DeltaQueue
{
	alias size_t_arr = ubyte[size_t.sizeof];

	this(size_t amt) {
		reserve(amt);
	}

	auto reserve(size_t amt) {
		return data.reserve(amt + (16*size_t.sizeof));
	}

	bool has_room(size_t num) {
		auto delta_can_fit = num > last_value && (num - last_value <= ubyte.max);
		auto needed_size  = delta_can_fit ? ubyte.sizeof : size_t.sizeof;
		return data.capacity > (data.length + needed_size);
	}

	bool has_room() {
		return data.capacity > (data.length + size_t.sizeof);
	}

	size_t push(size_t push_value) {
		debug {
			if(data.length >= data.capacity || !has_room(push_value)) {
				stderr.writeln("Warning: Will need to expand size of DeltaQueue (current length: ", data.length, ")");
			}
		}

		auto oldlen = data.length;
		if(data.length == 0)
		{
			data.length += size_t_arr.sizeof;
			data[0..size_t_arr.sizeof] = *(cast(size_t_arr*) (&push_value));
		}
		else if(last_value >= push_value || (last_value + ubyte.max) < push_value)
		{
			data.length += 1 + size_t_arr.sizeof;
			data[oldlen] = 0;
			data[oldlen+1 .. oldlen+size_t_arr.sizeof+1] = *(cast(size_t_arr*) (&push_value));
		}
		else
		{
			data.length += 1;
			ubyte delta = cast(ubyte)(push_value - last_value);
			data[oldlen] = delta;
		}
		last_value = push_value;
		length++;
		return length;
	}

	Range opSlice() {
		return Range(this.data, this.length);
	}

	struct Range {
		this(ubyte[] data, size_t length)
		{
			this.data = data;
			this._length = length;
			if(_length) {
				current_value = *(cast(size_t*) data.ptr);
				data_pos += size_t.sizeof;
			}
		}

		size_t front() {
			return current_value;
		}

		void popFront() {
			if(data_pos >= data.length) {
				data_pos++;
				return;
			}

			if(data[data_pos] == 0)
			{
				 //We've hit a marker zero; read the next size_t
				data_pos++;
				//current_value = *cast(size_t*)(data[data_pos..data_pos+size_t.sizeof].ptr);
				current_value = *(cast(size_t*)(&data[data_pos]));
				data_pos += size_t.sizeof;
			} else {
				// Normal delta value
				current_value += data[data_pos];
				data_pos++;
			}
		}

		auto length() { return this._length; }
		bool empty()  { return data_pos > data.length || data.length == 0; }

		private {
			ubyte[] data;
			size_t _length;
			size_t data_pos;
			size_t current_value;
		}
	}

	private {
		ubyte[] data;
		size_t length;
		size_t last_value;
	}
}

version(unittest) {
	import std.algorithm : equal;
	import std.range : iota, repeat;
}
unittest {
	DeltaQueue d;
	d.push(2);
	d.push(2);
	d.push(3);
	d.push(5);
	assert(equal(d[], [2, 2, 3, 5]));
}

unittest {
	DeltaQueue d;
	foreach(i; iota(100)) {
		d.push(i);
	}
	assert(equal(d[], iota(100)));
}

unittest {
	DeltaQueue d;
	foreach(_; 0..100) {
		d.push(0);
	}
	assert(equal(d[], repeat(0)[0..100]));
}

unittest {
	DeltaQueue d;
	d.push(100);
	d.push(1);
	d.push(25);
	d.push(0);
	d.push(10000);
	assert(equal(d[], [100, 1, 25, 0, 10000]));
}

unittest {
	DeltaQueue d;
	size_t[] empty = [];
	assert(equal(d[], empty));
}
