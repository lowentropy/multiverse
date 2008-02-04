@a = agent 'foo' do
	uid 'C904AB10-D762-E1E0-0566-E7453D3BEE9F'
	version '2.1.6'
	libs 'scripts/agents.rb'
end

state :default do
	start do
		MV.log :info, "activating agent"
		@a.load_server
		MV.log :info, "activated agent"
	end
end
