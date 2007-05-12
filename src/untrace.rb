$: << File.dirname(__FILE__)

module Untrace
	# remove the trace of the calling function from
	# the contained code
	def untraced(extra=0,before=0,&block)
		begin
			yield
		rescue
			# most recent first (smaller index)
			this = $!.backtrace.find {|line| /untraced/ =~ line}
			index = $!.backtrace.index this
			$!.backtrace[index-extra,2+extra+before] = []
			fail
		end
	end
end
