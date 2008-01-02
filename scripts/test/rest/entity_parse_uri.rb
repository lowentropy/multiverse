use! 'rest'
include REST

fun(:start) { quit }

entity(/a([0-9]+)z/,nil) do
	path :foo
	get { foo }
end

map_rest
