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
			block << proc { $stdout.write '' }
    	block << proc { @foo = 'foo' }
    	block << proc { assert_nil @sandbox }
			block << proc { assert_kind_of.call Sandbox, self }
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
		@sandbox.delegate :foo, self
		
		assert_equal 216, @sandbox.foo
	end

	def foo
		216
	end
	
	def bar
		foo
	end

	def test_two_levels
		val = []
		@sandbox.delegate :foo, self
		@sandbox.delegate :bar, self
		
		assert_equal 216, @sandbox.bar
	end

end
