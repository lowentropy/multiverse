$: << File.expand_path(File.dirname(__FILE__))

module REST

	module PatternInstance
		attr_reader :uri
		def redirect
			# TODO: return 302 to self.uri
		end
		def render
			@map = {}
			@attributes.each do |attr|
				@map[attr] = send attr
			end
			# TODO: render @map with requested media type or extension
		end
		def parse(path)
			m = @regex.match path
			@parts.map_with_index do |part,i|
				eval "@#{part} = m[i+1]"
			end
		end
	end

	# pattern root class
	class Pattern

		attr_reader :regex

		def initialize(regex, *actions)
			@regex = regex
			@visibility = :public
			@actions = actions
		end

		def path(*parts)
			@parts = parts
			parts.each do |part|
				@model.attr_reader part
				entity(part,nil) do
					# TODO: accessors should be more intelligent...
					# TODO: route should set @parent and @uri
					# TODO: set @path and @regex on @model
					show { @parent.send part }
					update { @parent.send "#{part}=", body }
				end
			end
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
			Thread.new(instance, block, globals) do |instance,block,globals|
				globals.each {|name,value| eval "$#{name} = value"}
				instance ? instance.instance_exec(&block) : block.call
			end.join
		end

		def handle(host, parent, instance, path, index)
			if path[index]
				route host, parent, instance, path, index
			else
				instance
			end
		end

		%w(public private).each do |mode|
			eval "def #{mode}; @visibility = :#{mode}; end"
		end
	end

end
