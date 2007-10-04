$: << File.expand_path(File.dirname(__FILE__) + '/..')

require 'environment'
require 'server'
require 'host'
require 'test/unit'

class ScriptTests < Test::Unit::TestCase

	def setup
		@server = Server.new :log => {:level => :debug}, 'port' => 4000
		@host = Host.new(nil, ['localhost', 4000])
	end

	def teardown
		return unless @server
		@server.shutdown
		@server.join
	rescue Mongrel::StopServer => e
	end

	def test_ordering
		@server.load :host, '../../scripts/test/ordering_test.rb'
		@server.start
		(1..100).each do |i|
			Thread.new(@server,@host,i) do |server,host,i|
				code, response = server.post host, '/order', :num => i
				assert_equal 200, code
			end
		end
		code, response = @server.post @host, '/list'
		assert_equal 200, code
		assert_equal (1..100).to_a, eval(response)
	end

	def run_ping(mode)
		@server.load :host, {:mode => mode},
			'../../scripts/test/ping_test.rb'

		@server.start

		code, response = @server.post @host, '/ping'
		puts "BODY: #{response}" if code != 200
		assert_equal 200, code
	end

	# mem is broken for some reason
	%w(net).each do |mode|
		define_method "test_ping_#{mode}" do
			run_ping(mode)
		end
	end
end
