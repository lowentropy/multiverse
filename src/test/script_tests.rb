$: << File.expand_path(File.dirname(__FILE__) + '/..')

require 'environment'
require 'server'
require 'host'
require 'test/unit'

class ScriptTests < Test::Unit::TestCase

	def setup
		puts "TEST: setting up..."
		@server = Server.new
		@host = Host.new(nil, ['localhost', 4000])
	end

	def teardown
		puts "TEST: shutting down..."
		@server.shutdown
		puts "TEST: joining..."
		@server.join
		puts "TEST: all done."
	rescue Mongrel::StopServer => e
		puts "TEST: stopped???"
	end

	def test_ping
		puts "TEST: loading scripts..."
		@server.load :host, {}, '../../scripts/test/ping_test.rb'
		sleep 1

		puts "TEST: starting server..."
		@server.start
		sleep 1

		puts "TEST: making request..."
		code, response = @server.post @host, '/ping'
		puts "BODY: #{response}" if code != 200
		assert_equal 200, code
	end

end
