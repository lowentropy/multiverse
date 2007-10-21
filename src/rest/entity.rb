$: << File.expand_path(File.dirname(__FILE__))

require 'rest'
require 'pattern'
require 'behavior'

module REST

	# Stateless client-side interface to an entity.
	# Sends requests over HTTP
	class EntityAdapter < Adapter
	end

	# Server-side entity instance methods
	module EntityInstance
		extend PatternInstance

		%w(show update delete).each do |method|
			handler_name = "#{method}_handler"
			private; define_method handler_name do
				begin
					vis, block = @pattern.instance_variable_get "@#{method}"
				rescue Exception => e
					puts e
					puts e.backtrace
				end
				if block
					assert_visibility vis
					block
				else
					# TODO: security checks for defaults?
					proc { default_get }
				end
			end
		end

		# default REST action
		def default_get
			render
		end

		# default REST action
		def default_put
			# TODO
		end

		# default REST action
		def default_delete
			# TODO
		end

		# REST responder
		def get
			reply :body => instance_exec(&show_handler)
		end

		# REST responder
		def put
			instance_exec &update_handler
		end

		# REST responder
		def delete
			instance_exec &delete_handler
		end

	end

	# a member of a store
	#		GET = show
	#		PUT = new/update
	#		DELETE = delete
	class Entity < Pattern

		class Empty; end

		def initialize(klass, regex, &block)
			super(regex, :show, :delete, :update, :new)
			@entity = klass || Empty
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

		# sub-pattern declaration
		def behavior(regex, &block)
			@behaviors << [@visibility, Behavior.new(regex, &block)]
		end

		# sub-pattern declaration
		def entity(regex, klass, &block)
			@entities << [@visibility, Entity.new(klass, regex, &block)]
		end

		# sub-pattern declaration
		def store(regex, klass, &block)
			@stores << [@visibility, Store.new(klass, regex, &block)]
		end

		# route a message within our RESTful structure.
		def route(parent, instance, path, index)
			%w(entity store behavior).each do |pattern|
        collection = instance_variable_get "@#{pattern.pluralize}"
				handler = route_to_pattern(collection, parent, instance, path, index)
				return handler if handler
			end
			nil
		end

		# method definer
		def get(&block)
			@show = [@visibility, block]
		end

		# method definer
		def update(&block)
			@update = [@visibility, block]
		end

		# method definer
		def delete(&block)
			@delete = [@visibility, block]
		end

		# TODO: other definers (???)
    
		# helper to route messages to a sub-pattern
		def route_to_pattern(collection, parent, instance, path, index)
			collection.each do |sub|
				visibility, klass = *sub
				if klass.regex =~ path[index]
					assert_visibility visibility
					new_instance = klass.instance(instance, path.subpath(index))
					return klass.handle(instance, new_instance, path, index+1)
				end
			end
		end

	end
end
