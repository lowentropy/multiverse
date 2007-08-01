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
				@entities << [@visibility, Entity.new(klass, eval("/#{regex_or_name}/"), &block)]
			end
		end

		# routers
		def route(host, parent, instance, path, index)
			%w(entity collection behavior).each do |pattern|
				return true if send "route_to_#{pattern}" host, parent, instance, path, index
			end
			return true if route_to_dynamic host, parent, instance, path, index
			false
		end

		%w(entity collection behavior).each do |pattern|
			define_method "route_to_#{pattern}" do |host,parent,instance,path,index|
				collection = instance_variable_get "@#{pattern.pluralize}"
				collection.each do |sub|
					vis, klass = *sub
					if sub.regex =~ path[index]
						host.assert_visibility vis
						return klass.handle host, instance, klass.instance, path, index+1
					end
				end
				false
			end
		end

		# dynamic routing
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
			instance.instance_exec *parts, &block
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
