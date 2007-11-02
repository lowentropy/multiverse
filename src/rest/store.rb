$: << File.expand_path(File.dirname(__FILE__))

require 'rest'
require 'pattern'
require 'entity'
require 'behavior'

module REST

	# functionality of server-side store instances
	module StoreInstance
		extend PatternInstance

		adapters %w(index find add)

		def default_index
			reply :code => 405
		end

		def default_find
			nil
		end

		# by default, the add action will try to determine the full
		# url of the entity to add from its parameters, assuming that
		# the path parts are present and a finder has been declared.
		# then try to call the 'new' handler on that entity.
		def default_add
			reply :code => 405 unless @finder
			parts = @pattern.entity.parts.map { params[part] }
			# TODO: make sure reply returns non-nil, mmkay?
			reply :code => 405 and return if parts.include? nil
			reply :code => 405 unless @finder.arity == parts.size
			entity = instance_exec parts, &finder
			reply :code => 405 unless entity
			entity.new
		end

		def get
			value = instance_exec(&index_handler)
			reply :body => value unless $env.replied?
		end

		def post
			instance_exec &add_handler
		end

	end

	# a store of a certain type of entity, and zero or more behaviors
	#		GET = index
	#		POST = add
	class Store < Pattern

		class Empty; end

		def initialize(klass, regex, &block)
			super(regex, :index, :find, :add)
			@store = klass || Empty
			@static = {}
			@behaviors = []
			create_instance(block)
		end

		%w(index find add).each do |method|
			define_method "#{method}_handler" do
				eval "@#{method}"
			end
		end

		# sub-pattern declarations
		def behavior(regex, &block)
			@behaviors << [@visibility, Behavior.new(regex, &block)]
		end

		# declare a dynamic or static entity inside this store
		def entity(regex_or_name, klass, &block)
			if regex.is_a? Regexp
				raise "only one regex entity declaration allowed" if @entity
				@entity = [@visibility, Entity.new(klass, regex_or_name, &block)]
			else
				@entities << [@visibility, Entity.new(klass, eval("/#{regex_or_name}/"), &block)]
			end
		end

		# routers
		def route(parent, instance, path, index)
			%w(entity collection behavior).each do |pattern|
				return true if send("route_to_#{pattern}", parent, instance, path, index)
			end
			return true if route_to_dynamic parent, instance, path, index
			false
		end

		%w(entity collection behavior).each do |pattern|
			define_method "route_to_#{pattern}" do |parent,instance,path,index|
				collection = instance_variable_get "@#{pattern.pluralize}"
				collection.each do |sub|
					vis, klass = *sub
					if sub.regex.match_all? path[index]
						assert_visibility vis
						return klass.handle(instance, klass.instance(instance, path[index]), path, index+1)
					end
				end
				false
			end
		end

		# dynamic routing
		def route_to_dynamic(parent, instance, path, index)
			if @entity.regex.match_all? path[index]
				object = find path[index]
				set_parent_and_path(object, instance, path[index])
				return(@entity.handle instance, object, path, index+1)
			end
			false
		end

		# set the indexing behavior
		def index(&block)
			@index = [@visibility, block]
		end

		# the find method is used internally when there
		# is a dynamic entity declaration with path elements
		def find(&block)
			@find = block
		end

		# define the method to add a member
		def add(&block)
			@add = block
		end

		# TODO: if a DELETE is called on a direct sub-entity of a store,
		# AND if that entity does not support DELETE, THEN the store's
		# user-definied @delete should run, returning 405 if none.

	end

end
