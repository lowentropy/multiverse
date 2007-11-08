require 'test/unit'
require 'src/ext'
require 'src/environment'
require 'src/server'
require 'src/host'
require 'src/agent'
require 'src/rest/rest'

class AgentTests < Test::Unit::TestCase
	def setup
		begin
			@server = Server.new :log => {:level => :fatal}, 'port' => 4000
			@host = @server.localhost
		rescue Exception => e
			puts e
			puts e.backtrace
		end
		@agent = Agent.new('foo') do
			version '2.1.6'
			uid '327A825D-4C37-6915-C0E8-F2DBD77AF170'
			libs
			code
		end
	end

	def teardown
		return unless @server
		@server.shutdown
		@server.join
	rescue Mongrel::StopServer => e
	end

	def test_adds_new_agent
		@server.load :host, {}, 'scripts/agents.rb'
		@server.start
		foo = '/agents/foo'.to_entity
		foo.put @agent.to_yaml
		assert_equal @agent.to_yaml, foo.get.to_yaml
	end

	def test_load_agent_from_script
		@server.load :test, {}, 'scripts/test/agent.rb'
		@server.start
	end

end
