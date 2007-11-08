require 'test/unit'
require 'src/ext'
require 'src/environment'
require 'src/server'
require 'src/host'
require 'src/rest/rest'

class StoreTests < Test::Unit::TestCase
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

	def test_should_load_store
		@server.load :agents, {}, "scripts/test/rest/store.rb"
		@server.start
		'/foo'.to_store.post '', :name => 'foo', :number => 216
	end

	def test_should_get_store_entity
		@server.load :host, {}, "scripts/test/rest/store.rb"
		@server.start
		entity = '/foo'.to_store['abc-123']
		entity.put
		assert_equal 'abc-123', entity.get
	end

	def test_automatic_entity
		@server.load :host, {}, "scripts/test/rest/store.rb"
		@server.start
		assert_equal 'blah', '/bar'.to_store['blah'].get
	end

	def test_auto_with_builtins_and_parent
		@server.load :host, {}, "scripts/test/rest/store.rb"
		@server.start
		assert_equal 'baz:quux', '/baz/quux'.to_rest.get
	end

	def test_non_matching_entity
		@server.load :host, {}, "scripts/test/rest/store.rb"
		@server.start
		assert_raise(REST::RestError) do
			'/foo/foo'.to_rest.get
		end
	end

	def test_add_and_delete
		@server.load :host, {}, "scripts/test/rest/store.rb"
		@server.start
		e = '/foo'.to_store['abc-123']
		assert_raise(REST::RestError) { e.get }
		assert_nothing_raised { e.put }
		assert_equal 'abc-123', e.get
		assert_nothing_raised { e.delete }
		assert_raise(REST::RestError) { e.get }
	end

end
