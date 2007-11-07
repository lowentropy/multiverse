require 'test/unit'
require 'src/ext'
require 'src/environment'
require 'src/server'
require 'src/host'
require 'src/rest/rest'

class BehaviorTests < Test::Unit::TestCase
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

	def test_should_call_toplevel_behavior
		@server.load :host, {}, "scripts/test/rest/behavior.rb"
		@server.start
		assert_equal '3', '/foo'.to_behavior.call('', :a => 1, :b => 2)
	end

	def test_should_call_store_behavior
		@server.load :host, {}, "scripts/test/rest/behavior.rb"
		@server.start
		assert_equal '3', '/bar'.to_store.foo.post('', :a => 1, :b => 2)
	end

	def test_should_call_dynamic_entity_behavior
		@server.load :host, {}, "scripts/test/rest/behavior.rb"
		@server.start
		res = '/baz'.to_store['gir'].foo.post '', :a => 1, :b => 2
		assert_equal 'gir: 3', res
	end

end
