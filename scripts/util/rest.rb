use 'rest'

entity(/util/) do
	entity(/random_uid/) do
		get { reply :body => UID.random }
	end
end.serve
