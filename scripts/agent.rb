module MV::Agents
	
	def agent(name, &block)
		Agent.new(name, &block)
	end
	
	def load_agent(name)
		MV.req "scripts/#{name}/agent.rb"
		eval "@#{name}_agent"
	end

	class Agent
		attr_reader :name
		def initialize(name=nil, &block)
			@name = name || '???'
			@libs, @code, @uid, @version = [], [], nil, nil
			class << self
				attr_reader :uid, :version, :libs, :code
			end
		end
		def uid(v); @uid = v; end
		def version(v); @version = v; end
		def libs(*v); @libs = v; end
		def code(*v); @code = v; end
		def load_server
			MV.load(name, libs+code)
		end
		def load_client
			MV.req(libs)
		end
	end
end

class << self
	include MV::Agents
end
