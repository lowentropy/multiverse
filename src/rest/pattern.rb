module REST

	class Attribute
	end

	# Methods shared by all server-side REST pattern instances.
  module PatternInstance
    attr_reader :uri
		attr_reader :parent
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
			#parts[0] = "--- mv,2007/rest/#{@pattern.type}:#{@uri}"
			parts[0].sub '{}', "mv,2007/rest/#{@pattern.type}:#{@uri}"
			parts.join "\n"
			# XXX to_yaml
		end
		# parse a fixed path into the named parts of our defining regex
    def parse(path)
			@pattern.parse(path).each do |part,value|
				eval "@#{part} = value"
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
		%w(get put post delete).each do |verb|
			define_method verb do
				reply :code => 405
			end
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
      @regex = regex.replace_uids
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
				parts = $env[:request_uri].split('/').reject {|p| p.empty?}
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

		def parse(path)
			map, m = {}, regex.match(path.split('/')[-1])
      parts.each_with_index do |part,i|
				map[part] = m[i + 1]
      end
			map
		end

		def render(value)
			return value.render if value.respond_to? :render
			return value if value.is_a?(String) && value[0,4] == '--- '
			value.to_yaml
		end

		def type
			self.class.name.split(':')[-1].downcase
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

		%w(int string float).each do |type|
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
#					XXX the below gave 'can't intern tainted string'
#					raise 'foo'
					uclass.send :define_method, "#{name}=" do |value|
						value = case type
							when :int then value.to_i
							when :float then value.to_f
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
				if part.is_a? Hash
					part.each do |key,val|
						case key
						when :trailing
							@trailing = val
							@model.send :attr_reader, @trailing
						end
					end
				else
					@model.send :attr_reader, part
					entity(/#{part}/, REST::Attribute) do
						get { @parent.send part }
					end
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
				%w(render).each do |fun|
					next unless @instance.respond_to? fun
					next unless mod.instance_methods.include? fun
					mod.send :remove_method, fun
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

		# run a pattern instance's handler for the message
    def run_handler(instance, *globals, &block)
      Thread.new(instance, block, globals) do |instance,block,globals|
        globals.each {|name,value| $env[name] = value}
        instance ? instance.instance_exec(&block) : block.call
      end.join
    end

		# handle a message by routing it until the target is found,
		# then calling run_handler.
    def handle(parent, instance, path, index)
			if @trailing
				trail = '/' + path[index..-1].join('/')
				$env.dbg "SET @#{@trailing} to #{trail.inspect}" # XXX
				instance.instance_variable_set "@#{@trailing}", trail
				instance
      elsif path[index]
        route parent, instance, path, index
      else
        instance
      end
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
