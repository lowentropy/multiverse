use! 'rest'
include REST

fun(:start) { quit }

class Foo; end

entity(/foo/, Foo) do
	attributes :a, :b, :c
end

map_rest
