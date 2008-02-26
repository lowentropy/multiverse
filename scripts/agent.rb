module MV::Agents
	
	def agent(name, &block)
		Agent.new(name, &block)
	end
	
	def load_agent(path)
		name = path.split('/')[-1]
		MV.req "scripts/#{path}/agent.rb"
		agent = instance_variable_get "@#{name}_agent"
		agent.path = path
		agent
	end

	class Agent
		attr_reader :name
		attr_accessor :path
		def initialize(name=nil, &block)
			@name = name || '???'
			@path = "scripts/#{name}"
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
			files.map {|f| "scripts/#{@path}/#{f}"}
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
