require 'test/unit'
require 'src/environment'

class EnvironmentTests < Test::Unit::TestCase

	def setup
		in_buf, out_buf = Buffer.new, Buffer.new
		# FIXME: this initialization sequence is STUPID.
		@env = Environment.new nil, nil, true
		@env.set_io out_buf, in_buf, 'MemoryPipe'
		@pipe = MemoryPipe.new in_buf, out_buf
		@env.add_script 'default', 'fun(:start) { }'
	end

	def test_join
		start = Time.now
		assert_nothing_raised do
			@env.run!
			sleep 1
			@env.shutdown!
			@env.join(0.3)
		end
		time = Time.now - start
		assert((time < 4), "join took too long (#{time}s)")
	end

	def test_fun_return_value
		@env.add_script 'foo', 'fun(:foo) { 216 }'
		assert_equal 216, @env.foo
	end

	def test_pipe_out_external
		$env = @env
		@env.run!
		"foo".to_host.put '/test', :param => 'value', :message_id => 0
		@pipe.read # :started
		assert_match(/PUT http:\/\/foo:4000\/test\?((param=value|message_id=0)&?)+/, @pipe.read.to_s)
		@env.shutdown!
		@env.join 0
	end

	def test_pipe_out_internal
		@env.add_script 'test', <<END
fun :test do
	'foo'.to_host.put '/test', :param => 'value', :message_id => 0
end
END
		@env.run!
		@env.test
		@pipe.read # :started
		assert_match(/PUT http:\/\/foo:4000\/test\?((param=value|message_id=0)&?)+/, @pipe.read.to_s)
		@env.shutdown!
		@env.join 0
	end

end
