$: << File.expand_path(File.dirname(__FILE__))

module REST

	# pattern root class
	class Pattern

		attr_reader :regex

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
			eval "def #{mode}; @visibility = :mode; end"
		end
	end

end
