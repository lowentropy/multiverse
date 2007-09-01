$: << File.expand_path(File.dirname(__FILE__))

require 'rest'
require 'pattern'
require 'behavior'

module REST

	# a member of a store
	#		GET = show
	#		PUT = new/update
	#		DELETE = delete
	class Entity << Pattern

		def initialize(klass, regex, &block)
			super(regex, :show, :delete, :update, :new)
			@entity = klass
			@entities = []
			@behaviors = []
			@stores = []
			@entity.extend PatternInstance
			instance_eval &block
		end

		# lazy init (because it's only used for singletons)
		def instance
			@instance ||= @entity.new
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
				return true if send "route_to_#{pattern}" host, parent, instance, path, index
			end
			false
		end

		%w(entity store behavior).each do |pattern|
			define_method "route_to_#{pattern}" do |host,parent,instance,path,index|
				collection = instance_variable_get "@#{pattern.pluralize}"
				collection.each do |sub|
					vis, klass = *sub
					if klass.regex =~ path[index]
						host.assert_visibility vis
						return klass.handle host, instance, klass.instance, path, index+1
					end
				end
				false
			end
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
	
end
