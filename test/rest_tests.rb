require 'test/unit'
require 'environment'
require 'server'
require 'host'
require 'rest/rest'

class RestTests < Test::Unit::TestCase
	def setup
		begin
			@server = Server.new :log => {:level => :fatal}, 'port' => 4000
			@host = @server.localhost
		rescue Exception => e
			puts e
			puts e.backtrace
		end
	end

	def teardown
		return unless @server
		@server.shutdown
		@server.join
	rescue Mongrel::StopServer => e
	end

	# repeat this test for:
	# foo top_behavior top_store
	def test_should_run_top_entity_through_rest
			@server.load :host, {}, "../../scripts/test/rest/top_entity.rb"
			sleep 0.5
			@server.start
			sleep 0.5
			code, response = @server.post @host, '/rest/test'
  		assert_equal 200, code, "Got unexpected response: '#{response}'"
  end
end
