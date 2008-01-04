$:.unshift File.dirname(__FILE__)
require 'sandbox'

class Script
	def initialize
		@sandbox = Sandbox.safe
		@sandbox.eval(%{
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
			reset
		})
	end
	def eval(str)
		@sandbox.eval str, :safelevel => 3, :timeout => 5
	end
	def run
		states = @sandbox.eval '@states'
		@sandbox.reset
		states.each do |state,events|
			events.each do |event,block|
				@sandbox.eval %{
					((@states||={})[:#{state}]||={})[:#{event}] = #{block.to_ruby}
				}
			end
		end
		@sandbox.eval %{
			def goto(new_state)
				raise 'bad state' unless @states[new_state]
				@state = new_state
				throw :goto
			end
			@state = @states.keys.first
		}
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
