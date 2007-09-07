$: << File.expand_path(File.dirname(__FILE__))

require 'rest'
require 'pattern'
require 'behavior'

module REST

	class EntityAdapter < Adapter
		def get
			code, body = $env.get @uri.to_s, '', {}
			raise RestError.new(code, body) if code != 200
			body
		end
		def put(body, params)
			code, body = $env.put @url, body, params
			raise RestError.new(code, body) if code != 200
		end
		def delete
			code, body = $env.delete @url, '', {}
			raise RestError.new(code, body) if code != 200
		end
	end

	module EntityInstance
		extend PatternInstance

		def show
			self.class.instance_variable_get :@show
		end

		# REST responders
		def get(host, parent, path)
			vis, block = @show
			host.assert_visibility vis
			reply = run_handler :path => path, &block
			host.reply_with reply
		end

		def put(host, parent, path, body, params)
			vis, block = @update
			host.assert_visibility vis
			reply = run_handler :path => path, :body => body, :params => params, &block
			host.reply_with reply
		end

		def delete(host, parent, path)
			vis, block = @delete
			host.assert_visibility vis
			run_handler :path => path, &block
			host.reply_with :nothing
		end
	end

	# a member of a store
	#		GET = show
	#		PUT = new/update
	#		DELETE = delete
	class Entity < Pattern

		def initialize(klass, regex, &block)
			super(regex, :show, :delete, :update, :new)
			@entity = klass || Class.new
			@entities = []
			@behaviors = []
			@stores = []
			@model = Module.new
			@model.extend EntityInstance
			@model.instance_variable_set :@entity, self
			instance_eval &block
			@instance = @entity.new # note: for singletons only
			@instance.extend @model
		end

		# sub-pattern declarations
		def behavior(regex, &block)
			@behaviors << [@visibility, Behavior.new(regex, &block)]
		end

		def entity(regex, klass, &block)
			@entities << [@visibility, Entity.new(klass, regex, &block)]
		end

		def store(regex, klass, &block)
			@stores << [@visibility, Store.new(klass, regex, &block)]
		end

		# routers
		def route(host, parent, instance, path, index)
			%w(entity store behavior).each do |pattern|
				return true if send("route_to_#{pattern}", host, parent, instance(parent, path), path, index)
			end
			false
		end

		# method definers
		def get(&block)
			@show = block
		end

		def update(&block)
			@update = block
		end

		def delete(&block)
			@delete = block
		end

		# TODO: other definers

		# sub-patterns
		%w(entity store behavior).each do |pattern|
			define_method "route_to_#{pattern}" do |host,parent,instance,path,index|
				collection = instance_variable_get "@#{pattern.pluralize}"
				collection.each do |sub|
					vis, klass = *sub
					if klass.regex =~ path[index]
						host.assert_visibility vis
						return klass.handle(host, instance, klass.instance(instance, path), path, index+1)
					end
				end
				false
			end
		end

	end
end
