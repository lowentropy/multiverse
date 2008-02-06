module MV::Agents
	
	def agent(name, &block)
		Agent.new(name, &block)
	end
	
	def load_agent(name)
		MV.req "scripts/#{name}/agent.rb"
		instance_variable_get "@#{name}_agent"
	end

	class Agent
		attr_reader :name
		def initialize(name=nil, &block)
			@name = name || '???'
			@libs, @code, @uid, @version = [], [], nil, nil
			self.instance_exec &block
			class << self
				attr_reader :uid, :version, :libs, :code
			end
		end
		def uid(v); @uid = v; end
		def version(v); @version = v; end
		def libs(*v); @libs = v; end
		def code(*v); @code = v; end
		def prep(files)
			files.map {|f| "scripts/#{@name}/#{f}"}
		end
		def load_server
			MV.load(name, *prep(libs+code))
		end
		def load_client
			MV.req(*prep(libs))
		end
	end
end

class << self
	include MV::Agents
end
