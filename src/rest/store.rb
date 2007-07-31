$: << File.expand_path(File.dirname(__FILE__))

require 'rest'
require 'pattern'
require 'entity'
require 'behavior'

module REST

	# a store of a certain type of entity, and zero or more behaviors
	#		GET = index
	#		POST = add
	class Store << Pattern

		attr_reader :instance

		def initialize(klass, regex, &block)
			super(regex, :index, :find, :add)
			@store = klass
			@static = {}
			@behaviors = []
			instance_eval &block
			create_instance
		end

		def create_instance
			@model = Module.new {}
			@model.instance_variable_set :store, self
			@model.extend StoreInstance
			@instance = @store.new
			@instance.extend @model
		end

		# sub-pattern declarations
		def behavior(regex, &block)
			@behaviors << [@visibility, Behavior.new(regex, &block)]
		end

		def entity(regex_or_name, klass, &block)
			if regex.is_a? Regex
				raise "only one regex entity declaration allowed" if @entity
				@entity = [@visibility, Entity.new(klass, regex_or_name, &block)]
			else
				@static[regex_or_name] = [@visibility, Entity.new(klass, regex_or_name, &block)]
			end
		end

		# structural stuff
		def route(host, parent, instance, path, index)
			return true if route_to_static host, parent, instance, path, index
			return true if route_to_behavior host, parent, instance, path, index
			return true if route_to_dynamic host, parent, instance, path, index
			false
		end

		def route_to_static(host, parent, instance, path, index)
			@static.each do |name,sub|
				vis, entity = *sub
				if path[index] == name.to_s
					host.assert_visibility vis
					return entity.handle host, instance, entity.instance, path, index+1
				end
			end
			false
		end

		def route_to_behavior(host, parent, instance, path, index)
			@behaviors.each do |name,sub|
				vis, behavior = *sub
				if path[index] == name.to_s
					host.assert_visibility vis
					return behavior.handle host, instance, nil, path, index+1
				end
			end
			false
		end

		def route_to_dynamic(host, parent, instance, path, index)
			if @entity.regex =~ path[index]
				object = find host, path[index]
				return @entity.handle host, instance, object, path, index+1
			end
			false
		end

		def find(host, path)
			parts = @entity.parse path
			vis, block = @find
			host.assert_visibility vis
			block.call *parts
		end

		# REST responders
		def get(host, path)
			vis, block = @index
			host.assert_visibility vis # TODO
			reply = run_handler :path => path, &block
			host.reply_with reply # TODO
		end
		def post(host, path, body, params)
			entity = @entity.new host, path, body, params
			vis, block = @add
			host.assert_visibility vis
			run_handler :path => path, :body => body, :params => params do
				block.call entity
			end
			host.reply_with :nothing
		end
	end

end
