require 'test/unit'
require 'src/ext'
require 'src/environment'
require 'src/server'
require 'src/host'
require 'src/rest/rest'

class RestTests < Test::Unit::TestCase
	def setup
		#add_trace
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

	def test_should_run_top_entity_through_rest
		@server.load :host, {}, "scripts/test/rest/top_entity.rb"
		@server.start
		
		code, response = @server.post @host, '/rest/test'
		assert_equal 200, code, "Got unexpected response: '#{response}'"
	end

	def test_should_set_and_get_entity_attributes
		@server.load :host, {}, "scripts/test/rest/entity_attr.rb"
		@server.start
		
		foo = '/foo'.to_entity

		%w(a b c).each do |attribute|
			field = foo.send attribute
			field.set '216'
			assert_equal '216', field.get
		end
	end	

	def test_should_set_attributes_and_get_entity
		@server.load :host, {}, "scripts/test/rest/entity_attr.rb"
		@server.start

		foo = '/foo'.to_entity
		foo.a.set 1
		foo.b.set 2
		foo.c.set 3

		sets = %w(:a:\ "1" :b:\ "2" :c:\ "3").permute
		assert sets.include?(foo.get.split(/\n/)[1..-1]),
			"invalid: #{foo.get.inspect}"
	end

	# isn't this test sexy?
	def test_active_entity
		@server.load :host, {}, "scripts/test/rest/entity_active.rb"
		@server.start

		foo = '/foo'.to_entity
		foo.a.set 3
		foo.b.set 7

		assert_equal '21', foo.c.get
	end
  
	def add_trace
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
		set_trace_func @trace
	end
  
end
