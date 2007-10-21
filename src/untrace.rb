$: << File.dirname(__FILE__)

# Untrace mixin provides the untrace method, which removes the
# calling function (and itself) from any stack trace arising inside
# the passed code block. Parameters can be tweaked to hide more
# entries outside or inside the untrace call.
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
