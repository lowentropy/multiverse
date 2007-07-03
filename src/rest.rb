class String
	def constantize
		begin
			eval self
		rescue
			nil
		end
	end
end

class Regex
	def replace_uids
		/#{source.gsub(/UID/,'[0-9a-fA-F]{16}')}/
	end
end

class Hash
	def to_stream
		inspect
	end
end


module REST

	def collection(regex, klass=nil, &block)
		new_rest :Collection, regex.handle_uids, klass, {:regex => regex}, &block
	end

	def behavior(regex, klass=nil, &block)
		new_rest :Behavior, regex.handle_uids, klass, {:regex => regex}, &block
	end

private

	def collections
		@collections ||= []
	end

	def new_rest(pattern, name, klass=nil, args={}, &block)
		name = name.to_s.capitalize
		klass ||= name.constantize || Class.new
		klass.extend eval("REST::#{pattern}")
		args.merge({:name => name}).each do |k,v|
			eval "klass.instance_eval {@#{k} = v}"
		end
		klass.instance_eval &block
		klass.register
	end

public

	module Collection
		
		def public
			@visibility = :public
		end

		def private
			@visibility = :private
		end

		def entity(regex, klass=nil, &block)
			@entity = new_rest :Entity, regex.handle_uids, klass, {:regex => regex}, &block
		end

		def register
			REST::collections << self
			REST::upstream :register, :collection => self
		end

		def to_hash
			{	:name => @name,
				:regex => @regex }
		end

		%w(index new get edit delete find add).each do |action|
			eval <<-END
				def #{action}(&block)
					@#{@visibility}[:#{action}] = block
				end
			END
		end

	end

	module Entity

		def behavior(regex, &block)
			@behaviors ||= []
			@behaviors << Behavior.new(regex, &block)
		end

		def path(*parts)
			@parts = parts
		end
		
		def public
			@visibility = :public
		end

		def private
			@visibility = :private
		end

		def register
			# do nothing
		end

		%w(new edit get delete).each do |action|
			eval <<-END
				def #{action}(&block)
					@#{@visibility}[:#{action}] = block
				end
			END
		def 

	end

	class Behavior

		def initialize(object, regex, &block)
			@regex = regex.replace_uids
			@block = block
		end

		def path(*parts)
			@parts = parts
		end

		def call(url)
			@match = @regex.match url
			object.instance_eval
		end

		def register
			# TODO
		end

	end
	
end
