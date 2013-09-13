module test_runner;

import std.stdio : writeln;

void main() {
	version(unittest) {
		writeln("All unittests pass");
	} else {
		static assert(false, "Must be run with unittests");
	}
}
