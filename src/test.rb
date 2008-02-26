$: << File.dirname(__FILE__)
require 'mv'
require 'script'

class TestScript < Script

	def initialize(name, options={})
		@name = name
		@sandbox = self
		@routes = {}
		@loaded, @loading = [], []
		extend Script::Definers
		@states = {}
		@state = nil
	end

	# TODO: add timeout and safelevel
	def eval(str, file="(top)", options={})
		$thread[:script] = self
		instance_eval str, file
	end

	def import(name_or_mod)
		if name_or_mod.is_a? Module
			extend name_or_mod
		else
			extend Kernel.eval(name_or_mod)
		end
	end

	def ref(mod)
	end

end
