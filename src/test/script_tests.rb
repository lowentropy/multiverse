$: << File.expand_path(File.dirname(__FILE__) + '/..')

require 'environment'
require 'server'
require 'host'
require 'test/unit'

class ScriptTests < Test::Unit::TestCase

	def setup
		@server = Server.new
		@server.start
		@host = Host.new(nil, ['localhost', 4000])
		sleep 0.1
	end

	def teardown
		@server.shutdown
		@server.join 1
	end

	def test_ping
		@server.load :host, {}, '../../scripts/test/ping_test.rb'
		sleep 1
		code, response = @server.post @host, '/test/ping/test?foo=bar'
		assert_equal 200, code
	end

end
