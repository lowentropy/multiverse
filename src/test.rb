require 'script'

class TestScript < Script

	def initialize(name, options={})
		@name = name
		@sandbox = self
		@routes = {}
		extend Script::Definers
		@states = {}
		@state = nil
	end

	def eval(str, options={})
		instance_eval str
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
