MV.req 'scripts/agent.rb'
load_agent('rest').load_client

class << self
	include REST
end

entity(/web/) do
	path :trailing => :address
	get do
		reply :body => File.read("public#{address}")
	end
end.serve
