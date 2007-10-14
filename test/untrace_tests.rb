require 'test/unit'
require 'untrace'
require 'environment'


class UntraceTests < Test::Unit::TestCase

	include Untrace

	def foo
		untraced(1) do
			bar
		end
	end

	def bar
		raise 'baz'
	end

	def test_untrace
		begin
			foo
		rescue
			assert $!.backtrace.join.index('foo').nil?, "foo not expected"
			assert !$!.backtrace.join.index('bar').nil?, "bar expected"
			assert !$!.to_s.index('baz').nil?, "expected baz"
		else
			assert false, "no error in trace"
		end
	end

	def test_env_untrace
		begin
			@env = Environment.new $stdin, $stdout, true
			@env.sandbox_check = false
			@env.add_script 'test', <<END
fun :foo do	
	raise "foo"
end
fun :bar do
	foo
end
fun :baz do
	bar
end
END
			@env.baz
		rescue RuntimeError => e
			assert_equal "test:2:in `foo'", e.backtrace[0]
			assert_equal "test:5:in `bar'", e.backtrace[1]
			assert_equal "test:8:in `baz'", e.backtrace[2]
		else
			assert false, "should have had error"
		end
	end
end
