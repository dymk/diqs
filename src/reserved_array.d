// ========================================================================
//module reserved_array;

/**
 * An array with a reserved amount of space to avoid lots of
 * reloactions. Also wraps some methods for removing items from the array.
 * Similar to appender, but lighter weight and more specialized.
 * For instance, don't retain slices that this returns; the internal data
 * structure it holds might be free'd for resizing.
 */

import std.array : empty;
import std.traits : Unqual;
import std.algorithm :
  equal,
  stdAlgoRemove = remove,
  copy;
import std.array : insertInPlace;
import core.memory : GC;


struct ReservedArray(T)
{
	this(size_t size_hint)
	{
		reserved_data = new T[size_hint];

		// This actually adds ~.1 seconds onto the runtime (for 100K images inserted)
		//import std.array : uninitializedArray;
		//reserved_data = uninitializedArray!(T[])(size_hint);
	}

	auto append(T thing) {
		if(used_capacity == reserved_data.length)
		{
			reserved_data ~= thing;
		}
		else
		{
			reserved_data[used_capacity] = thing;
		}
		used_capacity += 1;
		return used_capacity;
	}

	bool opEquals(const T[] other)
	{
		return equal(cast(Unqual!(T)[]) data, cast(Unqual!(T)[]) other);
	}

	void opAssign(T[] other)
	{
		if(reserved_data.length < other.length)
		{
			reserved_data = new T[other.length];
		}

		copy(other, reserved_data);
		used_capacity = other.length;
	}

	void opOpAssign(string op)(T rhs)
	if(op == "~")
	{
		append(rhs);
	}

	T[] opSlice()
	{
		return data;
	}

	void insertInPlace(size_t pos, T thing)
	in
	{
		assert(pos <= used_capacity);
	}
	body
	{
		reserved_data.insertInPlace(pos, thing);
		used_capacity++;
	}

	auto remove(size_t pos)
	in
	{
		assert(pos < used_capacity);
	}
	body
	{
		reserved_data = reserved_data.stdAlgoRemove(pos);
		used_capacity--;
		return data;
	}

	auto length()   @property { return used_capacity; }
	auto data()     @property { return reserved_data[0..used_capacity]; }
	auto capacity() @property { return reserved_data.length; }

	alias data this;

private:
	Unqual!T[] reserved_data;
	size_t used_capacity;
}

 //TODO: Get Optlink working with this, so this can be unittested under windows
version(unittest) {
	alias TestRArray = ReservedArray!int;
}

unittest {
	auto r = TestRArray(10);
	assert(r.capacity >= 10);
}

unittest {
	auto r = TestRArray(0);
	assert(r.empty);
	assert(r.length == 0);
}

unittest {
	auto r = TestRArray(0);
	r ~= 1;
	assert(r.length == 1);
	assert(r == [1]);
	assert(r[$-1] == 1);
}

unittest {
	auto r = TestRArray();
	assert(r.empty);
	assert(r.length == 0);
	assert(r == []);
}

unittest {
	auto r = TestRArray();
	r.append(1);
	assert(!r.empty);
	assert(r == [1]);
}

unittest {
	auto r = TestRArray();
	r ~= 1;
	assert(r == [1]);
}

unittest {
	auto r = TestRArray();
	r = [1, 2, 3, 4];
	assert(r == [1, 2, 3, 4]);
	assert(r.length == 4);
}

unittest {
	auto r = TestRArray();
	r = [1, 2, 3, 4];
	assert(r[] == [1, 2, 3, 4]);
}

unittest {
	auto r = TestRArray();
	r = [1, 2, 3, 4];
	r.remove(0);
	assert(r == [2, 3, 4]);
}

unittest {
	auto r = TestRArray();
	r.insertInPlace(0, 10);
	assert(r == [10]);
}

unittest {
	auto r = TestRArray();
	r = [1, 2, 3, 4];
	r.insertInPlace(0, 10);
	assert(r == [10, 1, 2, 3, 4]);
}
