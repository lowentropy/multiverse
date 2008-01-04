# This is a temporary replacement until why's sandbox
# is stable on x86_64. It implements a subset of why's API.

class Sandbox

	class TimeoutError < RuntimeError; end

	def self.safe(options={})
		self.new options
	end

	def inititalize(options={})
		@options = options
	end

	def eval(str, options={})
		options = @options.merge options
		safe, timeout = options[:safelevel], options[:timeout]
		if safe or timeout
			exc, timed_out = nil, false
			thread = Thread.start(str) do
				$SAFE = safe if safe and safe > $SAFE
				begin
					_eval str
				rescue Exception => exc
				end
			end
			thread.join timeout
			if thread.alive?
				thread.kill
				timed_out = true
			end
			if timed_out
				raise TimeoutError, "#{self.class}#eval timed out"
			elsif exc
				raise exc
			else
				thread.value
			end
		else
			_eval str
		end
	end

	def _eval(str)
		eval str
	end

end
