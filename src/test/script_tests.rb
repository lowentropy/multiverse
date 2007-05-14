$: << File.expand_path(File.dirname(__FILE__) + '/..')

require 'environment'
require 'server'
require 'test/unit'

class ScriptTests < Test::Unit::TestCase

	def setup
		@server = Server.new
		@server.start
		sleep 0.1
	end

	def teardown
		@server.shutdown
		@server.join
	end

	def test_receive_ping
		@server.load '../../scripts/test/ping_test.rb'
		response = @server.post 'localhost', '/test/ping/receive'
		assert_equal 200, response.status
	end

	def test_send_ping
		@server.load '../../scripts/test/ping_test.rb'
		response = @server.post 'localhost', '/test/ping/send'
		assert_equal 200, response.status
	end

end
