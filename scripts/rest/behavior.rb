# RESTful service API. See scripts/*.rb for examples
module REST

	class BehaviorAdapter < Adapter
		alias :call :post
	end

	class BehaviorInstance
		include PatternInstance
		def post
			reply :body => @pattern.render(instance_exec(&@pattern.block))
		end
	end

	# a behavior is a named action taking a POST
	#		POST = call
	class Behavior < Pattern

		attr_reader :block

		def initialize(regex, &block)
			super(regex)
			@block = block
			@instance = BehaviorInstance.new
			@instance.instance_variable_set :@pattern, self
		end
	end
	
end
