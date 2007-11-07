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
		def [](sub)
			"#{uri}/#{sub}".to_rest
		end
		alias :index :get
	end

	# functionality of server-side store instances
	module StoreInstance
		extend PatternInstance

		adapters %w(index find add delete)

		def default_index
			reply :code => 405
		end

		def default_find(*args)
			nil
		end

		def default_delete(entity)
			reply :code => 405
		end

		def entity
			@pattern.instance_variable_get(:@entity)[1]
		end

		def find(*parts)
			instance_exec *parts, &find_handler
		end

		def delete(entity)
			instance_exec entity, &delete_handler
		end

		def do_find(match)
			entity = @pattern.instance_variable_get(:@entity)[1]
			args = match[1, entity.parts.size]
			find *args
		end

		# due to the coding of post, this stub should never be called
		# def default_add
		# end

		def get
			value = instance_exec(&index_handler)
			reply :body => value unless $env.replied?
			value
		end

		# POSTing to a store has many possible behaviors. In order of
		# their precedence, they are:
		# 	- call the zero-argument user-defined add handler, if any
		# 	- if no add handler at all, call entity's PUT handler
		# 	- call entity's new handler [[and fail if that doesn't work]]
		# 	- call the one-argument add handler with the item, if any
		# 	- fail with 405 (FIXME: something more appropriate)
		def post
			entity = @pattern.instance_variable_get(:@entity)[1]
			add = @pattern.instance_variable_get(:@add)[1]
			return instance_exec(&add_handler) if add and add.arity == 0
			entity_path = entity.generate_path params
			item = entity.instance(self, entity_path, true)
			return if $env.replied?
			reply(:code => 405) and return unless item
			return item.put unless add
			item.new
			instance_exec item, &add_handler
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
			@entities = []
			create_instance(block)
		end

		%w(index find add delete).each do |method|
			define_method "#{method}_handler" do
				eval "@#{method}"
			end
		end

		# sub-pattern declarations
		def behavior(regex, &block)
			@behaviors << [@visibility, Behavior.new(regex, &block)]
		end

		# declare a dynamic or static entity inside this store
		# TODO: redoc
		def entity(regex, klass=nil, &block)
			@entities << @entity if @entity
			@entity = [@visibility, Entity.new(klass, regex, &block)]
		end

		# routers
		def route(parent, instance, path, index)
			%w(entity behavior).each do |pattern|
				inst = send("route_to_#{pattern}", parent,instance,path,index)
				return inst if inst
			end
			route_to_dynamic parent, instance, path, index
		end

		def route_to_entity(parent, instance, path, index)
			@entities.each do |entity|
				vis, klass = *entity
				inst = route_to_sub(vis, klass, parent, instance, path, index)
				return inst if inst
			end
			nil
		end

		def route_to_behavior(parent, instance, path, index)
			@behaviors.each do |behv|
				vis, klass = *behv
				inst = route_to_sub(vis, klass, parent, instance, path, index)
				return inst if inst
			end
			nil
		end

		def route_to_sub(vis, klass, parent, instance, path, index)
			return nil unless klass.regex.match_all? path[index]
			assert_visibility vis
			inst = klass.instance(instance, path[index])
			klass.handle(instance, inst, path, index+1)
		end

		# dynamic routing
		def route_to_dynamic(parent, instance, path, index)
			if (match = @entity[1].regex.match_all? path[index])
				item = instance.do_find match
				unless item
					if $env.params[:method] == :put and
						 index == (path.size - 1)
						$env.params[:method] = :post
						@entity[1].parse(path[-1]).each do |part,value|
							$env.params[part] = value
						end
						return instance
					end
					$env.reply :code => 404
					return nil
				end
				set_parent_and_path(item, instance, path[index])
				return @entity[1].handle(instance, item, path, index+1)
			end
			nil
		end

		# set the indexing behavior
		def index(&block)
			@index = [@visibility, block]
		end

		# the find method is used internally when there
		# is a dynamic entity declaration with path elements
		def find(&block)
			@find = [@visibility, block]
		end

		# define the method to add a member
		def add(&block)
			@add = [@visibility, block]
		end

		# define the method to delete a member
		def delete(&block)
			@delete = [@visibility, block]
		end

		# TODO: if a DELETE is called on a direct sub-entity of a store,
		# AND if that entity does not support DELETE, THEN the store's
		# user-definied @delete should run, returning 405 if none.

	end

end
