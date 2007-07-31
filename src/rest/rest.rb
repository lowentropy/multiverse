$: << File.expand_path(File.dirname(__FILE__))

require 'ext'
require 'pattern'
require 'store'
require 'entity'
require 'behavior'

# RESTful service patterns
module REST

public
	# top level pattern declarations
	def entity(name, klass, &block)
		raise "no dynamic names outside stores" unless name.is_a? Symbol
		(@entities ||= {})[name] = Entity.new(name, klass, &block)
	end
	def store(regex, klass, &block)
		(@stores ||= []) << Store.new(klass, regex, &block)
	end
	def behavior(regex, &block)
		(@behaviors ||= []) << Behavior.new(regex, &block)
	end

end
