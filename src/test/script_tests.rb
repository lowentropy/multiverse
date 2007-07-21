$: << File.expand_path(File.dirname(__FILE__) + '/..')

require 'environment'
require 'server'
require 'host'
require 'test/unit'

class ScriptTests < Test::Unit::TestCase

	def setup
		puts "setting up..."
		@server = Server.new
		@host = Host.new(nil, ['localhost', 4000])
	end

	def teardown
		puts "shutting down..."
		@server.shutdown
		@server.join 1
	rescue Mongrel::StopServer => e
	end

	def test_ping
		puts "loading scripts..."
		@server.load :host, {}, '../../scripts/test/ping_test.rb'
		sleep 1

		puts "starting server..."
		@server.start
		sleep 1

		puts "making request..."
		code, response = @server.post @host, '/test/ping/test?foo=bar'
		assert_equal 200, code
	end

end
