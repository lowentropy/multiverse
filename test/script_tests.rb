require 'src/environment'
require 'src/server'
require 'src/host'
require 'test/unit'

class ScriptTests < Test::Unit::TestCase
	def setup
		@server = Server.new :log => {:level => :error}, 'port' => 4000
    @host = @server.localhost
	end

	def teardown
		return unless @server
		@server.shutdown
		@server.join
	rescue Mongrel::StopServer => e
	end

	def run_ping(mode)
		@server.load :host, {:mode => mode}, 'scripts/test/ping_test.rb'
		@server.start

    code, response = @server.post @host, '/ping'
    
		assert_equal 200, code, "Got unexpected response: '#{response}'"
	end

  def test_should_ping_successfully_in_fifo_mode
    run_ping("fifo")
  end

  def test_should_ping_successfully_in_net_mode
    run_ping("net")
  end

  def test_should_ping_successfully_in_mem_mode
    run_ping("mem")
  end
    
end
