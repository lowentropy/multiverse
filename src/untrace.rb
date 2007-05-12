$: << File.dirname(__FILE__)

module Untrace
	# remove the trace of the calling function from
	# the contained code
	def untraced(n=3, &block)
		begin
			yield
		rescue
			$!.backtrace[1,n] = []
			fail
		end
	end
end
