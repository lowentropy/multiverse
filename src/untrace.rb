$: << File.dirname(__FILE__)

module Untrace
	# remove the trace of the calling function from
	# the contained code
	def untraced(extra=0,before=0,&block)
		begin
			yield
		rescue Exception => e
			# most recent first (smaller index)
			unless @full_trace
				this = e.backtrace.find {|line| /untraced/ =~ line}
				index = e.backtrace.index this
				e.backtrace[index-extra,2+extra+before] = []
			end
			fail e
		end
	end
end
