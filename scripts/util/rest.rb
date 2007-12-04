use! 'rest'

include REST

entity(/util/) do
	entity(/random_uid/) do
		get { reply :body => UID.random }
	end
end

map_rest

fun(:start) { quit }
