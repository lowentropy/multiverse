$: << File.expand_path(File.dirname(__FILE__))

require 'ext'

# RESTful service patterns
module REST

	# the two toplevel patterns are collections & behaviors
	def collection(regex, klass, &block)
		collections << Collection.new(klass, regex, &block)
	end
	def behavior(regex, &block)
		behaviors << Behavior.new(regex, &block)
	end

private
	# the rest module maintains a list of patterns at runtime
	def collections
		@collections ||= []
	end
	def behaviors
		@behaviors ||= []
	end

public
	# pattern root class
	class Pattern
		def initialize(regex, *actions)
			@regex = regex
			@visibility = :public
			@actions = actions
		end
		def method_missing(id, *args, &block)
			sym = id.id2name.to_sym
			if @actions.include? sym
				instance_variable_set sym, [@visibility, block]
			else
				super
			end
		end
		%w(public private).each {|mode| eval "def #{mode}; @visibility = :mode; end"}
	end

	# a collection of a certain type of entity, and zero or more behaviors
	#		GET = index
	#		PUT = add
	#		POST = find
	#		DELETE = delete
	class Collection << Pattern
		def initialize(klass, regex, &block)
			super(regex, :index, :find, :add, :delete)
			@collection = klass
			@behaviors = []
			instance_eval &block
		end
		def behavior(regex, &block)
			@behaviors << [@visibility, Behavior.new(regex, &block)]
		end
		def entity(regex, klass, &block)
			raise "only one entity declaration allowed" if @entity
			@entity = [@visibility, Entity.new(klass, regex, &block)]
		end
	end

	# a member of a collection
	#		GET = show
	#		PUT = new
	#		POST = update
	#		DELETE = delete
	class Entity << Pattern
		def initialize(klass, regex, &block)
			super(regex, :show, :delete, :update, :new)
			@entity = klass
			instance_eval &block
		end
	end
	
	# a behavior is a named action taking a POST
	#		POST = call
	class Behavior << Pattern
		def initialize(regex, &block)
			super(regex)
			@block = block
		end
	end
	
end
