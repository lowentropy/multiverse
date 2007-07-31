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
		# REST responders
		def post(host, path, body, params)
			reply = run_handler :path => path, :params => params, &@block
			host.reply_with reply
		end
	end
	
end
