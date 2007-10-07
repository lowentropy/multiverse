$: << File.expand_path(File.dirname(__FILE__))

module REST

  module PatternInstance
    attr_reader :uri
    def redirect
      $env.reply :code => 302, :body => uri
    end
    def render
      @map = {}
      @attributes.each do |attr|
        @map[attr] = send attr
      end
      # TODO: render @map with requested media type or extension
      # for now, rendering as yaml
      $env.reply :code => 200, :body => @map.to_yaml
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

    def map
      $env.handle @regex do
        self.handle nil, instance, $path.split('/'), 0
      end
    end

    def attributes(*attrs)
      attrs.each do |attribute|
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
        globals.each {|name,value| eval "$#{name} = value"}
        value = instance ? instance.instance_exec(&block) : block.call
        value.render if value && value.respond_to?(:render) # TODO: not for DELETE, others?
      end.join
    end

    def handle(parent, instance, path, index)
      if path[index]
        route parent, instance, path, index
      else
        instance
      end
    end

    def public
      @visibility = :public
    end

    def private
      @visibility = :private
    end
  end

end
