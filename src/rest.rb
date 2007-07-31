$: << File.expand_path(File.dirname(__FILE__))

require 'ext'

# RESTful service patterns
module REST

public
	# top level pattern declarations
	def entity(name, klass, &block)
		raise "no dynamic names outside stores" unless name.is_a? Symbol
		(@entities ||= {})[name] = Entity.new(name, klass, &block)
	end
	def store(regex, klass, &block)
		(@stores ||= []) << Store.new(klass, regex, &block)
	end
	def behavior(regex, &block)
		(@behaviors ||= []) << Behavior.new(regex, &block)
	end

	# pattern root class
	class Pattern
		def initialize(regex, *actions)
			@regex = regex
			@visibility = :public
			@actions = actions
		end
		def method_missing(id, *args, &block)
			sym = id.id2name.to_sym
			if @actions.include? sym
				instance_variable_set sym, [@visibility, block]
			else
				super
			end
		end
		def run_handler(instance, *globals, &block)
			Thread.new(self, block, globals) do |pattern,block,globals|
				globals.each {|name,value| eval "$#{name} = value"}
				instance.instance_eval &block
			end.join
		end
		%w(public private).each do |mode|
			eval "def #{mode}; @visibility = :mode; end"
		end
	end

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

		private
		def create_instance
			@model = Module.new {}
			@model.instance_variable_set :store, self
			@model.extend StoreInstance
			@instance = @store.new
			@instance.extend @model
		end

		public
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

		private
		# structural stuff
		def find(host, path)
			@static.each do |name,sub|
				vis, sub_pattern = *sub
				if path == name.to_s
					host.assert_visibility vis
					return sub_pattern.instance
				end
			end
			return nil unless @entity
			parts = @entity.parse path
			vis, block = @find
			host.assert_visibility vis
			block.call *parts
		end

		public
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

	# a member of a store
	#		GET = show
	#		PUT = new/update
	#		DELETE = delete
	class Entity << Pattern
		def initialize(klass, regex, &block)
			super(regex, :show, :delete, :update, :new)
			@entity = klass
			@behaviors = []
			instance_eval &block
			@model = Module.new {}
			@model.instance_variable_set :entity, self
			@model.extend ModelInstance
		end
		def behavior(regex, &block)
			@behaviors << [@visibility, Behavior.new(regex, &block)]
		end
		# REST responders
		def get(host, path)
			vis, block = @show
			host.assert_visibility vis
			reply = run_handler :path => path, &block
			host.reply_with reply
		end
		def put(host, path, body, params)
			vis, block = @update
			host.assert_visibility vis
			reply = run_handler :path => path, :body => body, :params => params, &block
			host.reply_with reply
		end
		def delete(host, path)
			vis, block = @delete
			host.assert_visibility vis
			run_handler :path => path, &block
			host.reply_with :nothing
		end
	end
	
	# a behavior is a named action taking a POST
	#		POST = call
	class Behavior << Pattern
		def initialize(regex, &block)
			super(regex)
			@block = block
		end
		# REST responders
		def post(host, path, body, params)
			reply = run_handler :path => path, :params => params, &@block
			host.reply_with reply
		end
	end
	
end
