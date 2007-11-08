require 'ext'
require 'yaml'

class Agent
	class Reader
		def initialize(agent)
			@agent = agent
		end
		def uid(uid)
			@agent.instance_variable_set :@uid, uid		
		end
		def version(version)
			@agent.instance_variable_set :@version, version
		end
		def libs(*files)
			@agent.instance_variable_set :@libs, self.class.read(files)
		end
		def code(*files)
			@agent.instance_variable_set :@code, self.class.read(files)
		end
		def self.read(files)
			map = {}
			files.each do |file|
				map[file] = File.read file
			end
			map
		end
	end
	attr_reader :name, :uid, :version
	def initialize(name=nil, &block)
		@name = name
		@libs = {}
		@code = {}
		@uid = nil
		@version = nil
		Reader.new(self).instance_exec &block if block
	end
	def render
		to_yaml
	end
	def to_yaml_type
		'!216brew.com,2007/mv/agent'
	end
	def to_yaml_properties
		%w(@name @uid @version @libs @code)
	end
	YAML.add_domain_type('216brew.com,2007','mv/agent') do |type,val|
		YAML.object_maker Agent, val
	end
end
