require 'test/unit'
require 'src/ext'
require 'src/environment'
require 'src/server'
require 'src/host'
require 'src/rest/rest'

class CacheTests < Test::Unit::TestCase
	def setup
		begin
			@server = Server.new :log => {:level => :fatal}, 'port' => 4000
			@host = @server.localhost
		rescue Exception => e
			puts e
			puts e.backtrace
		end
		@server.load :host, {}, "scripts/cache/agent.rb"
		@server.start
		sleep 0.5
		@cache = '/cache'.to_store
	end

	def teardown
		return unless @server
		@server.shutdown
		@server.join
	rescue Mongrel::StopServer => e
	end

	def assert_code(code, &block)
		ok = false
		begin
			val = yield
		rescue REST::RestError => e
			assert_equal code, e.code
			ok = true
		end
		assert ok, "got #{val} instead of #{code}"
	end

	def test_should_index_empty_cache
		assert_equal [], @cache.index
		assert_equal 0, @cache.size.get
	end

	def test_should_add_and_get_and_delete_item
		uid = UID.random
		item = @cache[uid]
		assert_code(404) { item.get }
		item.put '', :data => 'foo'
		assert_equal 1, @cache.size.get
		assert_equal [uid.to_s], @cache.index
		assert_equal 'foo', item.get
		item.delete
		assert_equal 0, @cache.size.get
		assert_equal [], @cache.index
		assert_code(404) { item.get }
	end

	def test_should_allow_update_by_nobody
		item = @cache[UID.random]
		item.put '', :data => 'foo'
		assert_equal 'foo', item.get
		item.put '', :data => 'bar'
		assert_equal 'bar', item.get
	end

	def test_should_allow_update_by_owner
		item = @cache[UID.random]
		item.put '', :data => 'foo'
		assert_equal 'foo', item.get
		item.put '', :data => 'bar', :owner => 'bob'
		assert_equal 'bar', item.get
		item.put '', :data => 'baz', :owner => 'bob'
		assert_equal 'baz', item.get
	end

	def test_should_not_allow_upate_by_non_owner
		item = @cache[UID.random]
		item.put '', :data => 'foo', :owner => 'bob'
		assert_equal 'foo', item.get
		assert_code(401) { item.put '', :data => 'baz', :owner => 'ted' }
		assert_equal 'foo', item.get
	end
	
	def test_should_get_uid_of_cache_item
		uid = UID.random
		item = @cache[uid]
		item.put
		assert_equal uid, item.uid.get
		assert_code(404) { @cache[UID.random].uid.get }
	end

end
