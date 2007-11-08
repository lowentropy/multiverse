fun(:start) { quit }

class Agents
	attr_reader :agents
	def initialize
		@agents = {}
	end
end

store(/agents/,Agents) do
	# TODO:
	#   init { @agents = {} }
	index { @agents.keys }
	find {|name| @agents[name]}
	add {|agent| @agents[agent.name] = agent}
	delete {|agent| @agents.delete agent.name}
	entity(/(.+)/,Agent) do
		path :name
		new { from_yaml body }
		get { render }
	end
	# TODO: behavior should run on code of parent
end

map_rest
