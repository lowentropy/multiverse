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
			files.map do |file|
				[file, File.read(file)]
			end
		end
	end
	attr_reader :name, :uid, :version, :libs, :code
	def initialize(name=nil, &block)
		@name = name
		@libs = []
		@code = []
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
	def to_message
		[:load_agent, nil, nil, {:agent => to_yaml}, [], []]
	end
	def activate
		$env << to_message
	end
	def activate!
		message = to_message
		$env << message
		begin
			Thread.pass while message[-2].empty?
		rescue Exception => e
			puts e
			puts e.backtrace
			fail
		end
	end
	YAML.add_domain_type('216brew.com,2007','mv/agent') do |type,val|
		YAML.object_maker Agent, val
	end
end
