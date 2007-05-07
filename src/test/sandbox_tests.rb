$: << File.expand_path(File.dirname(__FILE__) + '/..')

require 'test/unit'
require 'sandbox'


class SandboxTests < Test::Unit::TestCase

	def setup
		@sandbox = Sandbox.new
	end

	def test_safe
		# arguments to pass into thread
		block = [].taint
		kind_of = proc {|k,o| assert_kind_of k, o}
		is_nil = proc {|o| assert_nil o}

		# set up SAFE=4 -level blocks
		Thread.new(block,kind_of,is_nil) do |block,assert_kind_of,assert_nil|
			$SAFE = 4
			block << proc do
				$stdout.write ''
			end
			block << proc do
				@foo = 'foo'
			end
			block << proc do
				assert_nil @sandbox
			end
			block << proc do
				assert_kind_of.call Sandbox, self
			end
		end.join
		
		# no printing in safe blcok
		assert_raise SecurityError do
			@sandbox.sandbox &block[0]
		end

		# no out-of-scope access in sandbox
		assert_raise NoMethodError do
			@sandbox.sandbox &block[2]
		end

		# sandbox writable
		assert_nothing_raised do
			@sandbox.sandbox &block[1]
		end

		# sandbox 'self' is correct
		assert_nothing_raised do
			@sandbox.sandbox &block[3]
		end

		# SAFE-level doesn't go out of scope
		assert_nothing_raised do
			$stdout.write ''
		end
	end

	def test_variable
		@sandbox['foo'] = 'foo'
		@sandbox['bar'] = (bar = [])
		@sandbox.sandbox do
			@bar << @foo
		end
		assert_equal 'foo', bar[0]
	end

	def test_function
		val = []
		fun = proc do
			val << 216
		end
		@sandbox[:fun] = fun
		@sandbox.fun
		assert_equal 216, val[0]
	end

	def test_two_levels
		val = []
		@sandbox[:foo] = proc { val << 216 }
		@sandbox[:bar] = proc { foo }
		@sandbox.bar
		assert_equal 216, val[0]
	end

end
