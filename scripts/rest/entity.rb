module REST

	# Stateless client-side interface to an entity.
	# Sends requests over HTTP
	class EntityAdapter < Adapter
	end

	# TODO: make params a hash that calls to_s on keys

	# Server-side entity instance methods
	module EntityInstance
		extend PatternInstance

		adapters %w(show update delete new)

		# default non-REST action
		def default_new
			attrs = @pattern.instance_variable_get :@attributes
			attrs.each do |attr|
				eval "@#{attr} = params[attr]"
			end
		end

		def new
			instance_exec &new_handler
			self
		end

		# default REST action
		def default_show
			self
		end

		# default REST action
		def default_update
			reply :code => 405
		end

		# default REST action
		def default_delete
			@parent.delete(self)
		end

		# REST responder
		def get
			value = @pattern.render(instance_exec(&show_handler))
			reply :body => value unless $env.replied?
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

		def from_path(*parts)
			inst = @instance.clone
			@parts.each_with_index do |part,i|
				inst.instance_variable_set "@#{part}", parts[i]
			end
			inst
		end

		%w(show update delete new).each do |method|
			define_method "#{method}_handler" do
				eval "@#{method}"
			end
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

		def new(&block)
			@new = [@visibility, block]
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
				if klass.regex.match_all? path[index]
					assert_visibility visibility
					new_instance = klass.instance(instance, path.subpath(index))
					return klass.handle(instance, new_instance, path, index+1)
				end
			end
			nil
		end

	end
end
