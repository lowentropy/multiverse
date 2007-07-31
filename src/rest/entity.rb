$: << File.expand_path(File.dirname(__FILE__))

require 'rest'
require 'pattern'
require 'behavior'

module REST

	# a member of a store
	#		GET = show
	#		PUT = new/update
	#		DELETE = delete
	class Entity << Pattern
		def initialize(klass, regex, &block)
			super(regex, :show, :delete, :update, :new)
			@entity = klass
			@behaviors = []
			instance_eval &block
			@model = Module.new {}
			@model.instance_variable_set :entity, self
			@model.extend ModelInstance
		end
		def behavior(regex, &block)
			@behaviors << [@visibility, Behavior.new(regex, &block)]
		end
		# REST responders
		def get(host, path)
			vis, block = @show
			host.assert_visibility vis
			reply = run_handler :path => path, &block
			host.reply_with reply
		end
		def put(host, path, body, params)
			vis, block = @update
			host.assert_visibility vis
			reply = run_handler :path => path, :body => body, :params => params, &block
			host.reply_with reply
		end
		def delete(host, path)
			vis, block = @delete
			host.assert_visibility vis
			run_handler :path => path, &block
			host.reply_with :nothing
		end
	end
	
end
