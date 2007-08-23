$: << File.expand_path(File.dirname(__FILE__) + '/..')

require 'test/unit'
require 'ext'


class InstanceExecTests < Test::Unit::TestCase

	class Foo
		def initialize
			@bar = 216
		end
	end

	def setup
		@foo = Foo.new
	end

	def test_instance_funs_similarity
		block = proc { @bar }
		assert_equal 216, @foo.instance_eval(&block)
		assert_equal 216, @foo.instance_exec(&block)
	end

	def test_instance_exec_with_params
		block = proc {|n| ([@bar.to_s + '!'] * n).join ' '}
		assert_equal '216! 216! 216!', @foo.instance_exec(3, &block)
	end

end