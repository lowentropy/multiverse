$: << File.expand_path(File.dirname(__FILE__))

require 'rest'
require 'pattern'
require 'entity'
require 'behavior'

module REST
	#
	# Stateless client-side interface to a store.
	# Sends requests over HTTP
	class StoreAdapter < Adapter
	end

	# functionality of server-side store instances
	module StoreInstance
		extend PatternInstance

		adapters %w(index find add)

		def default_index
			reply :code => 405
		end

		def default_find(*args)
			reply :code => 405
		end

		# due to the coding of post, this stub should never be called
		# def default_add
		# end

		def get
			value = instance_exec(&index_handler)
			reply :body => value unless $env.replied?
		end

		# POSTing to a store has many possible behaviors. In order of
		# their precedence, they are:
		# 	- call the zero-argument user-defined add handler, if any
		# 	- if no add handler at all, call entity's PUT handler
		# 	- call entity's new handler, and fail if that doesn't work
		# 	- call the one-argument add handler with the item, if any
		# 	- fail with 405 (FIXME: something more appropriate)
		def post
			entity = @pattern.instance_variable_get(:@entity)[1]
			return instance_exec(&add_handler) if @add and @add.arity == 0
			entity_path = entity.generate_path params
			puts "ENTITY PATH: #{entity_path} from #{params.inspect}"
			item = entity.instance(self, entity_path, true)
			return if $env.replied?
			reply(:code => 405, :body => "can't gen!") and return unless item
			@add ? instance_exec(item,&add_handler) : item.put
		end

	end

	# TODO: check action arity at define-time

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
		def entity(regex_or_name, klass=nil, &block)
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
		#
		# type of pattern we are
		def type
			'store'
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
			if (match = @entity.regex.match_all? path[index])
				item = instance.do_find match
				unless item
					# TODO: if it's a PUT, try a POST on us instead
					# otherwise, find out how to return a 404 from here
				end
				set_parent_and_path(item, instance, path[index])
				return(@entity.handle instance, item, path, index+1)
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
