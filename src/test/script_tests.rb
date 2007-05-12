$: << File.expand_path(File.dirname(__FILE__) + '/..')

require 'environment'
require 'test/unit'

class ScriptTests < Test::Unit::TestCase

	def setup
		#@host = Server.new
		#@env = @host.env
		@env = Environment.new *IO.pipe
		$env = @env
	end

	def test_receive_ping
		@env.add_script '../../scripts/test/ping_test.rb'
		assert_nil @env.test_receive_ping
	end

	def test_send_ping
		@env.add_script '../../scripts/test/ping_test.rb'
		assert_nil @env.test_send_ping
	end

end
