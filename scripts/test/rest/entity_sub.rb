fun(:start) { quit }

entity(/foo/,nil) do
	get { 'foo' }
	entity(/bar/,nil) do
		get { 'bar' }
		entity(/baz/,nil) do
			get { 'baz' }
		end
	end
end

map_rest
