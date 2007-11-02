fun(:start) { quit }

class Foo; end

entity(/foo|bar|baz{1,3}/, Foo) do
	get { '216' }
end

map_rest
