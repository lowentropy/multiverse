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
			@static = {}
			@behaviors = []
			instance_eval &block
			@model = Module.new {}
			@model.instance_variable_set :entity, self
			@model.extend ModelInstance
		end

		# sub-pattern declarations
		def behavior(regex, &block)
			@behaviors << [@visibility, Behavior.new(regex, &block)]
		end

		def entity(name, klass, &block)
			raise "no dynamic entities outside stores" unless name.is_a? Symbol
			@static[name] = [@visibility, Entity.new(klass, name, &block)]
		end

		# structural stuff
		def route(host, parent, instance, path, index)
			return true if route_to_entity host, parent, instance, path, index
			return true if route_to_behavior host, parent, instance, path, index
			false
		end

		def route_to_entity(host, parent, instance, path, index)
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
			@behaviors.each do |sub|
				vis, behavior = *sub
				if behavior.regex =~ path
					host.assert_visibility vis
					return behavior.handle host, instance, nil, path, index+1
				end
			end
			false
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
