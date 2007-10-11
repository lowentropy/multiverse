require 'test/unit'
require 'src/environment'
require 'src/server'
require 'src/host'
require 'src/rest/rest'

class RestTests < Test::Unit::TestCase
	def setup
		begin
			@server = Server.new :log => {:level => :debug}, 'port' => 4000
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
  # top_behavior top_store
  
  def test_should_run_top_entity_through_rest
      @server.load :host, {}, "scripts/test/rest/top_entity.rb"
      sleep 0.5
      @server.start
      sleep 0.5
      
      #code, response = @server.post @host, '/rest/test'
			#puts "TEST: got code #{code}" # XXX
      #assert_equal 200, code, "Got unexpected response: '#{response}'"
    end
  
  # def test_should_run_foo_through_rest
  #   @server.load :host, {:mode => "fifo"}, "scripts/test/rest/foo.rb"
  #   sleep 0.5
  #   @server.start
  #   sleep 0.5
  # 
  #   # assert_equal "", @host.env#.sandbox.entities
  #   code, response = @server.post @host, '/rest/test'
  # 
  #   assert_equal 200, code, "Got unexpected response: '#{response}'"
  # end
  
end
