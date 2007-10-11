$: << File.expand_path(File.dirname(__FILE__))

require 'rest'
require 'pattern'
require 'behavior'

module REST

	class EntityAdapter < Adapter
	  attr_reader :uri
	  def env
	    $env
    end
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

		%w(show update delete).each do |method|
			handler_name = "#{method}_handler"
			private; define_method handler_name do
				vis, block = @pattern.send handler_name
				if block
					assert_visibility vis
					block
				else
					# TODO: security checks for defaults?
					proc { default_get }
				end
			end
		end

		# default REST actions
		def default_get
			render
		end

		def default_put
			# TODO
		end

		def default_delete
			# TODO
		end

		# REST responders
		def get
			reply :body => show_handler.call
		end

		def put
			update_handler.call
			get # XXX ???
		end

		def delete
			delete_handler.call
			get # XXX ???
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
			create_instance(block)
		end

		%w(show update delete).each do |method|
			define_method "#{method}_handler" do
				eval "@#{method}"
			end
		end

		# type of pattern we are
		def type
			'entity'
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
		def route(parent, instance, path, index)
			%w(entity store behavior).each do |pattern|
        collection = instance_variable_get "@#{pattern.pluralize}"
				handler = route_to_pattern(collection, parent, instance(parent, path), path, index)
				return handler if handler
			end
			nil
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
    
		def route_to_pattern(collection, parent, instance, path, index)
			collection.each do |sub|
				visability, klass = *sub
				if klass.regex =~ path[index]
					assert_visibility visability
					return klass.handle(instance, klass.instance(instance, path), path, index+1)
				end
			end
			nil
		end

	end
end
