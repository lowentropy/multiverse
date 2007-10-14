$: << File.expand_path(File.dirname(__FILE__))

module REST

  module PatternInstance
    attr_reader :uri
		def path
			$env[:path]
		end
		def params
			$env.params
		end
		def body
			$env[:body]
		end
		def method
			$env[:method]
		end
    def redirect
      $env.reply :code => 302, :body => uri
    end
		def attributes
			@pattern.instance_variable_get :@attributes
		end
		# XXX i'm not sure if this is recommended... just for debugging...
		def reply(*args)
			$env.reply *args
		end
    def render
      @map = {}
      attributes.each do |attr|
        @map[attr] = send attr
      end
      # TODO: render @map with requested media type or extension
      # for now, rendering as yaml FIXME incorrect yaml: no obj type/name?
			@map.to_yaml
    end
    def parse(path)
      m = @regex.match path
      @parts.map_with_index do |part,i|
        eval "@#{part} = m[i+1]"
      end
    end
		def to_s
			"#<#{@pattern.type}:#{@uri}>"
		end
		alias :inspect :to_s
		def assert_visibility(visibility)
			# TODO
		end

  end

  # pattern root class
  class Pattern

    attr_reader :regex

    def initialize(regex, *actions)
      @regex = regex
      @visibility = :public
      @actions = actions
			@attributes = []
    end

    def map
			$env.dbg "mapping REST handler #{@regex.source} to #{self}"
      $env.listen @regex, self do
				$env.dbg "in rest listener, self = #{self}"
				# FIXME: this here is damn ugly (and stupid)
				$env[:path] = $env.params[:request_uri]
				parts = $env[:path].split('/').reject {|p| p.empty?}
        handler = self.handle nil,
					instance(nil,$env[:path]), parts[1..-1], 0
				if handler
					$env[:method] = $env.params.delete :method
					$env[:body] = $env.params.delete :body
					handler.send $env[:method]
				else
					$env.reply :code => 404, :body => $env[:path]
				end
      end
    end

    def attributes(*attrs)
      attrs.each do |attribute|
				@attributes << attribute
        @model.send :attr_accessor, attribute
        entity(attribute,nil) do
          get { @parent.send attribute }
          update { @parent.send "#{attribute}=", body }
        end
      end
    end

    def path(*parts)
      @parts = parts
      parts.each do |part|
        @model.send :attr_reader, part
        entity(part,nil) do
          get { @parent.send part }
          update { @parent.send "#{part}=", body }
        end
      end
    end

    def instance(parent, path)
      set_parent_and_path(@instance, parent, path)
    end

		def create_instance(block)
			@model = Module.new
			instance_eval &block
			@instance = eval("@#{type}").new
			@instance.instance_variable_set :@pattern, self
			@instance.extend PatternInstance
			@instance.extend eval("#{type.capitalize}Instance")
			@instance.extend @model
		end

    def set_parent_and_path(object, parent, path)
      object.instance_variable_set :@parent, parent
      object.instance_variable_set :@uri, path
      object
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
        globals.each {|name,value| $env[name] = value}
        value = instance ? instance.instance_exec(&block) : block.call
        value.render if value && value.respond_to?(:render) # TODO: not for DELETE, others?
      end.join
    end

    def handle(parent, instance, path, index)
      val = if path[index]
        route parent, instance, path, index
      else
        instance
      end
			$env.dbg "handler for #{instance} at #{path[index]} is #{val}"
			val
    end

    def public
      @visibility = :public
    end

    def private
      @visibility = :private
    end
  end

end
