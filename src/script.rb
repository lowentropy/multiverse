require 'sandbox'
require 'rubygems'
require 'ruby2ruby'

require 'mv'

# A state machine in a f.f.sandbox.
class Script

	# top-level define-time methods for scripts
	module Definers
		# declare a state
		def state(name, &block)
			raise 'nested states' if @state
			@states[name.to_sym] = {}
			@state = name.to_sym
			yield
			@state = nil
		end
		# unknown names are handlers
		def method_missing(id, *args, &block)
			return super if args.any? or @state.nil?
			@states[@state][id.id2name.to_sym] = block
		end
	end

	# top-level run-time methods for scripts
	module Runners
		# run the state machine; return last evaluated
		# expression after a goto
		def __main
			@state = :default
			while true
				event = :start
				block = @states[@state][event]
				raise 'no block' unless block
				result = nil
				catch(:goto) do
					result = block.call
				end
				break if result
			end
			result
		end
		# handle an http request
		def __handle(id, body, params, headers)
			raise "bad route id #{id}" unless @routes[id]
			@routes[id].call body, params, headers
		end
		# jump to a new state
		def goto(new_state)
			raise 'bad state' unless @states[new_state]
			@state = new_state
			throw :goto
		end
		# re-defines the define-time method-missing
		def method_missing(id, *args)
			raise "no such method #{id.id2name}"
		end
		# trigger a script handler
		def trigger(action)
			if (block = @states[state][action])
				block.call
			else
				raise "no action #{action} in state #{state}"
			end
		end
		# returns the current state; also hides the define-time version
		def state
			@state
		end
	end

	# create a new script
	def initialize
		@sandbox = Sandbox.safe
		import 'Script::Definers'
		eval '@states = {}; @state = nil'
	end

	# evaluate script text
	def eval(str)
		raise "can't load while running" if @running
		@sandbox.eval str, :safelevel => 3, :timeout => 5
	end

	# explicitly declare a state
	def state(name, &block)
		eval "state :#{name}, &(#{block.to_ruby})"
	end

	# import a module into the script
	def import(name)
		@sandbox.import Kernel.eval(name)
		@sandbox.eval "class << self; include #{name}; end; nil"
	end

	# load text into script, as given name
	def load(name, text)
		eval(text)
	end

	# reset state definitions
	def reset
		eval "@states = {}; @state = nil"
	end

	%w(quit pause abort).each do |action|
		define_method action do
			@sandbox.eval "__#{action}"
		end
	end

	# handle an http request
	def handle(id, body, params, headers)
		args = [id, body, params, headers]
		@sandbox.eval "__handle(*#{args.inspect})"
	end

	# run the state machine
	def run
		unless @ran
			import 'Script::Runners'
			@sandbox.import MV
			@sandbox.eval 'self.taint'
			@ran = true
		end
		@sandbox.eval '__main', :safelevel => 4
	end
end
