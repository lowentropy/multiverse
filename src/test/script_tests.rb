$: << File.expand_path(File.dirname(__FILE__) + '/..')

require 'environment'
require 'server'
require 'host'
require 'test/unit'

class ScriptTests < Test::Unit::TestCase

	def setup
		sleep 0.5
		@server = Server.new :log => {:level => :fatal}, 'port' => 4000
		@host = Host.new(nil, ['localhost', 4000])
	end

	def teardown
		return unless @server
		@server.shutdown
		@server.join
	rescue Mongrel::StopServer => e
	end

	def run_ping(mode)
		@server.load :host, {:mode => mode},
			'../../scripts/test/ping_test.rb'

		sleep 0.5
		@server.start
		sleep 0.5

		code, response = @server.post @host, '/ping'
		puts "BODY: #{response}" if code != 200
		assert_equal 200, code
	end

	# mem is broken for some reason
	%w(fifo net).each do |mode|
		define_method "test_ping_#{mode}" do
			run_ping(mode)
		end
	end
end
