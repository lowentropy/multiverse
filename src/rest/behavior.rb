$: << File.expand_path(File.dirname(__FILE__)

require 'rest'
require 'pattern'

module REST

	# a behavior is a named action taking a POST
	#		POST = call
	class Behavior << Pattern

		def initialize(regex, &block)
			super(regex)
			@block = block
		end

		# structural stuff
		def route(*args)
			nil
		end
		
		# REST responders
		def post(host, parent, path, body, params)
			reply = run_handler parent, :path => path, :params => params, &@block
			host.reply_with reply
		end
	end
	
end
