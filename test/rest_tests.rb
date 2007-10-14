require 'test/unit'
require 'src/environment'
require 'src/server'
require 'src/host'
require 'src/rest/rest'

class RestTests < Test::Unit::TestCase
	def setup
		last_msg = nil
		@trace = proc do |event,file,line,id,bind,klass|
			begin
				break unless /c-call/i =~ event.to_s
				break unless /pass/i =~ id.to_s
				break unless /server/i =~ file.to_s
				break unless line == 402

				msg = eval("msg", bind)
				puts "(#{line}) waiting for reply to #{msg}" unless msg == last_msg
				last_msg = msg

				#if /c-call/ =~ event.to_s && /pass/i =~ id.to_s
				#	printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, klass
				#end
			rescue Exception => e
				puts "bad news..."
				puts e
				puts e.backtrace
			end
		end
		#set_trace_func @trace
		begin
			@server = Server.new :log => {:level => :fatal}, 'port' => 4000
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
      
      code, response = @server.post @host, '/rest/test'
      assert_equal 200, code, "Got unexpected response: '#{response}'"
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
