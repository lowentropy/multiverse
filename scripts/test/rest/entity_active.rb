fun(:start) { quit }

class Foo
	def c
		a * b
	end
end

entity(/foo/, Foo) do
	int :a, :b, :c
end

map_rest
