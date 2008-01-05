require 'sandbox'

class Script

	module Definers
		def reset
			@state = nil
			@states = {}
		end
		def state(name, &block)
			@states[name.to_sym] = {}
			@state = name.to_sym
			yield
		end
		def method_missing(id, *args, &block)
			return super if args.any? or @state.nil?
			@states[@state][id.id2name.to_sym] = block
		end
	end

	def initialize
		@sandbox = Sandbox.safe
		@sandbox.import Script::Definers
		@sandbox.eval 'class << self; include Script::Definers; end; reset'
	end
	def eval(str)
		@sandbox.eval str, :safelevel => 3, :timeout => 5
	end
	module Runners
		def goto(new_state)
			raise 'bad state' unless @states[new_state]
			@state = new_state
			throw :goto
		end
		def method_missing(id, *args)
			raise "no such method #{id.id2name}"
		end
		def state
			@state
		end
	end
	def run
		@sandbox.eval %{
			@state = @states.keys.first
		}
		@sandbox.import Script::Runners
		@sandbox.eval 'class << self; include Script::Runners; def reset; end; end; nil'
		@sandbox.eval %{
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
		}, :safelevel => 4
	end
end
