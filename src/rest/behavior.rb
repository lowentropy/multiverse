$: << File.expand_path(File.dirname(__FILE__))

require 'rest'
require 'pattern'

# RESTful service API. See scripts/*.rb for examples
module REST

	class BehaviorAdapter < Adapter
		alias :call :post
	end

	class BehaviorInstance
		include PatternInstance
		def post
			reply :body => instance_exec(&@pattern.block)
		end
	end

	# a behavior is a named action taking a POST
	#		POST = call
	class Behavior < Pattern

		attr_reader :block

		def initialize(regex, &block)
			super(regex)
			@block = block
			#@model = Class.new(BehaviorInstance)
			#@model.instance_variable_set :@behavior, self
			@instance = BehaviorInstance.new # @model.new
			@instance.instance_variable_set :@pattern, self
		end

		def type
			'behavior'
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
