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
		@server.load :host, {}, "scripts/cache.rb"
		@server.start
		@cache = '/cache'.to_store
	end

	def teardown
		return unless @server
		@server.shutdown
		@server.join
	rescue Mongrel::StopServer => e
	end

	def assert_404(&block)
		ok = false
		begin
			val = yield
		rescue REST::RestError => e
			assert_equal 404, e.code
			ok = true
		end
		assert ok, "got #{val} instead of 404"
	end

	def test_should_index_empty_cache
		assert_equal '', @cache.index
		assert_equal '0', @cache.size.get
	end

	def test_should_add_and_get_and_delete_item
		uid = UID.random
		item = @cache[uid]
		assert_404 { item.get }
		item.put '', :data => 'foo'
		assert_equal '1', @cache.size.get
		assert_equal uid.to_s, @cache.index
		assert_equal 'foo', item.get
		item.delete
		assert_equal '0', @cache.size.get
		assert_equal '', @cache.index
		assert_404 { item.get }
	end

end
