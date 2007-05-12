$: << File.expand_path(File.dirname(__FILE__) + '/..')

require 'test/unit'
require 'untrace'


class UntraceTests < Test::Unit::TestCase

	include Untrace

	def foo
		untraced do
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

end
