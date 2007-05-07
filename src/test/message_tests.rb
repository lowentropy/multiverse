$: << File.expand_path(File.dirname(__FILE__) + '/..')

require 'message'
require 'test/unit'


class MessageTests < Test::Unit::TestCase

	def setup
		@msg = Message.new :foo, 'bar', 'baz', {}
	end

	def reload
		Message.unmarshal @msg.marshal
	end

	def test_int
		@msg[:an_int] = 216
		assert_equal 216, reload[:an_int]
	end

	def test_sym
		@msg[:a_sym] = :symbol
		assert_equal :symbol, reload[:a_sym]
	end

	def test_float
		@msg[:a_float] = 3.14
		assert_equal 3.14, @msg[:a_float]
	end

	def test_plain
		@msg[:param_1] = 'abc'
		@msg[:param_2] = 'def'
		msg = reload
		assert_equal :foo, msg.command
		assert_equal 'bar', msg.host
		assert_equal 'baz', msg.url
		assert_equal 'abc', msg[:param_1]
		assert_equal 'def', msg[:param_2]
	end

	def test_multiline
		@msg.host = "the\nhost"
		@msg.url = "the\nurl"
		msg = reload
		assert_equal "the\nhost", msg.host
		assert_equal "the\nurl", msg.url
	end

end
