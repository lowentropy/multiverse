$: << File.expand_path(File.dirname(__FILE__))

module REST

	class Attribute
	end

	# Methods shared by all server-side REST pattern instances.
  module PatternInstance
    attr_reader :uri
		# actual (request) path to instance
		# FIXME these are sandbox-local!
		def path
			$env[:path]
		end
		# parameters passed to instance in a call
		def params
			$env.params
		end
		# body of request passed to instance
		# FIXME these are sandbox-local!
		def body
			$env[:body]
		end
		# method of request to instance
		# FIXME these are sandbox-local!
		def method
			$env[:method]
		end
		# issue a 302 reply to own static path
    def redirect
      $env.reply :code => 302, :body => uri
    end
		# get the builtin attributes of the pattern
		def attributes
			@pattern.instance_variable_get :@attributes
		end
		# XXX i'm not sure if this is recommended... just for debugging...
		def reply(*args)
			$env.reply *args
			true
		end
		# TODO: render @map with requested media type or extension
		# for now, rendering as yaml FIXME incorrect yaml? no obj type/name?
    def render
      @map = {}
      attributes.each do |attr|
        @map[attr] = send attr
      end
			parts = @map.to_yaml.split(/\n/)
			parts[0] = "--- #{@pattern.type}:#{@uri}"
			parts.join "\n"
    end
		# parse a fixed path into the named parts of our defining regex
    def parse(path)
      m = @pattern.regex.match path.split('/')[-1]
      @pattern.parts.each_with_index do |part,i|
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
		private
		def adapters(methods)
			methods.each do |method|
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
						proc {|*args| send "default_#{method}", *args }
					end
				end
			end
		end
  end

  # pattern root class
  class Pattern

    attr_reader :regex, :parts

    def initialize(regex, *actions)
      @regex = regex
      @visibility = :public
      @actions = actions
			@attributes = []
			@parts = []
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
					instance(nil, parts.subpath(0)), parts, 1
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
    def attributes(*attrs)
      attrs.each do |attribute|
				if attribute.kind_of? Hash
					attribute.each do |a,type|
						add_attribute a, type
					end
				else
					add_attribute attribute, :string
				end
      end
    end

		%w(int string).each do |type|
			define_method type do |*attrs|
				hash = {}
				attrs.each do |a|
					hash[a] = type.to_sym
				end
				attributes hash
			end
		end

		# add an attribute of the given type. if there is not already a
		# function of this name in the user class, an acceessor is added
		# which honors the given type (currently only :string or :int).
		# this funciton adds a new entity of the given name, and attaches
		# its actions to the parent pattern instance.
		def add_attribute(name, type)
			@attributes << name
			uclass = eval "@#{self.type}"
			entity(/#{name}/, REST::Attribute) do
				read, write = false, false
				if uclass.instance_methods.include? name.to_s
					read = true
					write = true if uclass.instance_methods.include? "#{name}="
				else
					read, write = true, true
					uclass.send :attr_reader, name
					# TODO find out why this works but not the one below
#					uclass.instance_eval <<-END
#						def #{name}=(value)
#							value = case :#{type}
#								when :int then value.to_i
#								else value
#							end
#							@#{name} = value
#						end
#					END
#					XXX the below gave 'can't intern tainted string'
#					raise 'foo'
					uclass.send :define_method, "#{name}=" do |value|
						value = case type
							when :int then value.to_i
							else value
						end
						eval "@#{name} = value"
					end
				end
				get { @parent.send name } if read
				update { @parent.send "#{name}=", body } if write
			end
		end

		# declare named sections of the path to the resource,
		# to be used as (non-queryable) attributes.
    def path(*parts)
      @parts = parts
      parts.each do |part|
        @model.send :attr_reader, part
        entity(/#{part}/, REST::Attribute) do
          get { @parent.send part }
        end
      end
    end

		# re-generate a possible source path from the regex and
		# the parameters. if any parameters are missing, return nil.
		def generate_path(params)
			path = @regex.source
			@parts.each do |part|
				return nil unless params[part]
				path.sub! /\([^)]+\)/, params[part]
			end
			path
		end

		# get an initialized reference to the instance of the
		# pattern to be used to receive messages.
    def instance(parent, path, clone=false)
			return nil unless path
			inst = clone ? @instance.clone : @instance
      set_parent_and_path(inst, parent, path)
    end

		# create a new instance of this pattern (singleton).
		# clone the instance if you want more.
		def create_instance(block)
			@model = Module.new
			instance_eval &block
			klass = eval "@#{type}"
			pattern = eval "#{type.capitalize}Instance"
			@instance = klass.new
			@instance.instance_variable_set :@pattern, self
			[PatternInstance, pattern, @model].each do |mod|
				mod = mod.clone
				if @instance.respond_to?(:render) &&
						mod.instance_methods.include?('render')
					mod.send :remove_method, :render
				end
				@instance.extend mod
			end
			@instance
		end

		# set @parent and @uri on the instance
    def set_parent_and_path(object, parent, path)
      object.instance_variable_set :@parent, parent
      object.instance_variable_set :@uri, path
			object.parse path
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
        value.render if value && value.respond_to?(:render)
				# TODO: not for DELETE, others?
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

		# assert that a call is valid for protection scope
		def assert_visibility(vis)
			# TODO
		end
  end

end
