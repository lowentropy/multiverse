require 'test/unit'
require 'src/ext'
require 'src/environment'
require 'src/server'
require 'src/host'
require 'src/rest/rest'

class RestTests < Test::Unit::TestCase
	def setup
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

	def test_active_entity
		@server.load :host, {}, "scripts/test/rest/entity_active.rb"
		@server.start

		foo = '/foo'.to_entity
		foo.a.set 3
		foo.b.set 7

		assert_equal '21', foo.c.get
	end

	def test_dynamic_entity_name
		@server.load :host, {}, "scripts/test/rest/entity_dynamic_name.rb"
		@server.start

		%w(/foo /bar /baz /bazzz).each do |name|
			assert_nothing_raised do
				assert_equal '216', name.to_entity.get
			end
		end

		%w(/asdf /monkey /bazzzz).each do |name|
			assert_raise REST::RestError do
				name.to_entity.get
				puts "#{name} succeeded!"
			end
		end
	end
  
end
