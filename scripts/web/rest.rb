use 'rest'

entity(/web/) do
	path :trailing => :address
	get do
		reply :body => File.read("public#{address}")
	end
end.serve
