$: << File.expand_path(File.dirname(__FILE__))

require 'rest'
require 'pattern'
require 'entity'
require 'behavior'

module REST

	module StoreInstance
		extend PatternInstance
		# TODO
	end

	# a store of a certain type of entity, and zero or more behaviors
	#		GET = index
	#		POST = add
	class Store < Pattern

		def initialize(klass, regex, &block)
			super(regex, :index, :find, :add)
			@store = klass
			@static = {}
			@behaviors = []
			@model = Module.new {}
			@model.instance_variable_set :@store, self
			@model.extend StoreInstance
			instance_eval &block
			create_instance
		end

		def create_instance
			@instance = @store.new
			@instance.extend @model
		end

		# sub-pattern declarations
		def behavior(regex, &block)
			@behaviors << [@visibility, Behavior.new(regex, &block)]
		end

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
					if sub.regex =~ path[index]
						assert_visibility vis
						return klass.handle(instance, klass.instance(instance, path[index]), path, index+1)
					end
				end
				false
			end
		end

		# dynamic routing
		def route_to_dynamic(parent, instance, path, index)
			if @entity.regex =~ path[index]
				object = find path[index]
				set_parent_and_path(object, instance, path[index])
				return(@entity.handle instance, object, path, index+1)
			end
			false
		end

		def find(path)
			parts = @entity.parse path
			vis, block = @find
			assert_visibility vis
			instance.instance_exec *parts, &block
		end

		# REST responders
		def get(path)
			vis, block = @index
			assert_visibility vis
			run_handler :path => path, &block
		end

		def post(path, body, params)
			entity = @entity.new path, body, params
			vis, block = @add
			assert_visibility vis
			run_handler :path => path, :body => body, :params => params do
				block.call entity
			end
		end
	end

end
