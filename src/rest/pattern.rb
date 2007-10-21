$: << File.expand_path(File.dirname(__FILE__))

module REST

	# Methods shared by all server-side REST pattern instances.
  module PatternInstance
    attr_reader :uri
		# actual (request) path to instance
		def path
			$env[:path]
		end
		# parameters passed to instance in a call
		def params
			$env.params
		end
		# body of request passed to instance
		def body
			$env[:body]
		end
		# method of request to instance
		def method
			$env[:method]
		end
		# issue a 302 reply to own static path
    def redirect
      $env.reply :code => 302, :body => uri
    end
		# get the builtin attributes of the pattern
		# (XXX does this make sense for non-entities?)
		def attributes
			@pattern.instance_variable_get :@attributes
		end
		# XXX i'm not sure if this is recommended... just for debugging...
		def reply(*args)
			$env.reply *args
		end
		# TODO: render @map with requested media type or extension
		# for now, rendering as yaml FIXME incorrect yaml? no obj type/name?
    def render
      @map = {}
      attributes.each do |attr|
        @map[attr] = send attr
      end
			@map.to_yaml
    end
		# parse a fixed path into the named parts of our defining regex
    def parse(path)
      m = @regex.match path
      @parts.map_with_index do |part,i|
        eval "@#{part} = m[i+1]"
      end
    end
		# pretty-print a reference
		def to_s
			"#<#{@pattern.type}:#{@uri}>"
		end
		alias :inspect :to_s
		# assert that the request is allowed for this resource
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

		# take the API definition and send messages to the environment, and
		# thence to the server, that initialize routes for global requests to
		# reach the pattern instance.
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

		# define builtin attributes of the pattern
		# (XXX does this make sense for non-entities?)
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

		# declare named sections of the path to the resource,
		# to be used as (non-queryable) attributes.
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

		# get an initialized reference to the instance of the
		# pattern to be used to receive messages.
    def instance(parent, path)
      set_parent_and_path(@instance, parent, path)
    end

		# create a new instance of this pattern (singleton)
		def create_instance(block)
			@model = Module.new
			instance_eval &block
			@instance = eval("@#{type}").new
			@instance.instance_variable_set :@pattern, self
			@instance.extend PatternInstance
			@instance.extend eval("#{type.capitalize}Instance")
			@instance.extend @model
		end

		# set @parent and @uri on the instance
    def set_parent_and_path(object, parent, path)
      object.instance_variable_set :@parent, parent
      object.instance_variable_set :@uri, path
      object
    end

		# XXX what the hell is this?
    def method_missing(id, *args, &block)
      sym = id.id2name.to_sym
      if @actions.include? sym
        instance_variable_set sym, [@visibility, block]
      else
        super
      end
    end

		# run a pattern instance's handler for the message
    def run_handler(instance, *globals, &block)
      Thread.new(instance, block, globals) do |instance,block,globals|
        globals.each {|name,value| $env[name] = value}
        value = instance ? instance.instance_exec(&block) : block.call
        value.render if value && value.respond_to?(:render) # TODO: not for DELETE, others?
      end.join
    end

		# handle a message by routing it until the target is found,
		# then calling run_handler.
    def handle(parent, instance, path, index)
      val = if path[index]
        route parent, instance, path, index
      else
        instance
      end
			$env.dbg "handler for #{instance} at #{path[index]} is #{val}"
			val
    end

		# set visibility
    def public
      @visibility = :public
    end

		# set visibility
    def private
      @visibility = :private
    end
  end

end
