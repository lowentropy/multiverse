$: << File.expand_path(File.dirname(__FILE__) + '/..')

require 'environment'
require 'server'
require 'host'
require 'test/unit'

class ScriptTests < Test::Unit::TestCase

	def setup
		@server = Server.new :log => {:level => :fatal}, 'port' => 4000
		@host = Host.new(nil, ['localhost', 4000])
	end

	def teardown
		return unless @server
		@server.shutdown
		@server.join
	rescue Mongrel::StopServer => e
	end

	def test_ping
		@server.load :host, {}, '../../scripts/test/ping_test.rb'
		sleep 0.5
		@server.start
		sleep 0.5

		code, response = @server.post @host, '/test/ping'
		puts "BODY: #{response}" if code != 200
		assert_equal 200, code
	end

end
