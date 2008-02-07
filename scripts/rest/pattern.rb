module REST

	class Attribute; end

	# Methods shared by all server-side REST pattern instances.
  module PatternInstance
    attr_reader :uri, :parent
		%w(path params body method).each do |var|
			define_method MV.sym(var) do
				request[var.to_sym]
			end
		end
		def request
			$thread[:request]
		end
		def get_var(name)
			instance_variable_get "@#{name}"
		end
		def set_var(name, value)
			instance_variable_set "@#{name}", value
		end
		def attributes
			@pattern._attributes
		end
		def reply(*args)
			@reply = args
			true
		end
		# TODO: render @map with requested media type or extension
		# for now, rendering as yaml.
		def render
			@map = {}
			attributes.each do |attr|
				@map[attr] = send attr
			end
			parts = @map.to_yaml.split(/\n/)
			parts[0].sub '{}', "mv,2007/rest/#{@pattern.type}:#{@uri}"
			parts.join "\n"
		end
		# parse a fixed path into the named parts of our defining regex
    def parse(path)
			@pattern.parse(path).each do |part,value|
				instance_variable_set "@#{part}", value
			end
    end
		# pretty-print a reference
		def to_s
			"#<#{@pattern.type}:#{@uri}>"
		end
		alias :inspect :to_s
		%w(get put post delete).each do |verb|
			define_method MV.sym(verb) do
				if @pattern.verbs[verb]
					value = instance_exec(&@pattern.verbs[verb][1])
					reply :body => @pattern.render(value) unless @reply
				else
					reply :code => 405, :body => "#{self} doesn't allow #{verb}"
				end
			end
		end
		private
		# these wrap user-defined verbs
		def adapters(methods)
			methods.each do |method|
				define_method MV.sym("#{method}_handler") do
					block = @pattern.send "_#{method}"
					block ? block : proc do |*args|
						send "default_#{method}", *args
					end
				end
			end
		end
  end

  # pattern root class
  class Pattern

    attr_reader :regex, :parts, :verbs

    def initialize(regex, *actions)
      @regex = regex.replace_uids
      @actions = actions
			@attributes = []
			@parts = []
			@verbs = {}
    end

		# take the API definition and send messages to the script, and
		# thence to the server, to initialize routes for global requests to
		# reach the pattern instance.
    def map
			block = proc do |request|
				parts = request.path.url_split
				top_inst = instance nil, parts.subpath(0)
        inst = self.handle nil, top_inst, parts, 1
				if inst
					$thread[:request] = request
					inst.send method
					return @reply
				end
				{:code => 404, :body => "no handler for #{path}"}
      end
			MV.map(/^\/#{@regex.source}/, block)
    end

		alias :serve :map

		def parse(path)
			parts = path.url_split
			map, m = {}, regex.match(parts[-1])
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
			type = MV.sym(type)
			define_method type do |*attrs|
				hash = {}
				attrs.each do |a|
					hash[a] = type
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
			uclass = instance_variable_get "@#{self.type}"
			entity(/#{name}/, REST::Attribute) do
				read, write = false, false
				if uclass.instance_methods.include? name.to_s
					read = true
					write = true if uclass.instance_methods.include? "#{name}="
				else
					read, write = true, true
					uclass.send :attr_reader, name
					uclass.send :define_method, MV.sym("#{name}=") do |value|
						value = case type
							when :int then value.to_i
							when :float then value.to_f
							else value
						end
						instance_variable_set "@#{name}", value
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
		# TODO: this won't work for entities with :trailing
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
			klass = instance_variable_get "@#{type}"
			pattern = REST.const_get "#{type.capitalize}Instance"
			@instance = klass.new
			[PatternInstance, pattern, @model].each do |mod|
				mod = mod.clone
				%w(render).each do |fun|
					next unless @instance.respond_to? fun
					next unless mod.instance_methods.include? fun
					mod.send :remove_method, fun
				end
				@instance.extend mod
			end
			@instance.set_var :pattern, self
			@instance
		end

		# set @parent and @uri on the instance
    def set_parent_and_path(object, parent, path)
      object.set_var :parent, parent
      object.set_var :uri, path
			object.parse path
      object
    end

		# handle a message by routing it until the target is found
    def handle(parent, instance, path, index)
			if @trailing
				trail = '/' + path[index..-1].join('/')
				instance.instance_variable_set "@#{@trailing}", trail
				instance
      elsif path[index]
        route parent, instance, path, index
      else
        instance
      end
    end

		def verb(v, &block)
			@verbs[v.to_s] = block
		end
  end

end
