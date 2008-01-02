use! 'rest'

include REST

entity(/web/) do
	path :trailing => :address
	get do
		reply :body => File.read("public#{address}")
	end
end

map_rest

fun(:start) { quit }
