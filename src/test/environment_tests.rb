$: << File.expand_path(File.dirname(__FILE__) + '/..')

require 'test/unit'
require 'environment'


class EnvironmentTests < Test::Unit::TestCase

	def setup
		@host_in, @pipe_out = IO.pipe
		@pipe_in, @host_out = IO.pipe
		@env = Environment.new @pipe_in, @pipe_out
		@pipe = MessagePipe.new @host_in, @host_out
		@env.add_script 'default', 'fun(:start) { }'
	end

	def test_join
		start = Time.now
		assert_nothing_raised do
			@env.run
			sleep 1
			@env.shutdown!
			@env.join(0.3)
		end
		assert((Time.now - start < 3), "join took too long")
	end

	def test_fun_return_value
		@env.add_script 'foo', 'fun(:foo) { 216 }'
		assert_equal 216, @env.foo
	end

	def test_pipe_out_external
		$env = @env
		@env.run
		"foo".to_host.put '/test', :param => 'value'
		assert_equal "PUT foo/test?param=value", @pipe.read.to_s
		@env.shutdown!
		@env.join 0
	end

	def test_pipe_out_internal
		@env.add_script 'test', <<END
fun :test do
	'foo'.to_host.put '/test', :param => 'value'
end
END
		@env.run
		@env.test
		assert_equal "PUT foo/test?param=value", @pipe.read.to_s
		@env.shutdown!
		@env.join 0
	end

end
