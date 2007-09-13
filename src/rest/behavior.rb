$: << File.expand_path(File.dirname(__FILE__))

require 'rest'
require 'pattern'

module REST

	class BehaviorInstance
		include PatternInstance
		# TODO
	end

	# a behavior is a named action taking a POST
	#		POST = call
	class Behavior < Pattern

		def initialize(regex, &block)
			super(regex)
			@block = block
			@model = Class.new(BehaviorInstance)
			@model.instance_variable_set :@behavior, self
			@instance = @model.new
		end

		# structural stuff
		def route(*args)
			nil
		end
		
		# REST responders
		def post(parent, path, body, params)
			run_handler parent, :path => path, :params => params, &@block
		end
	end
	
end
