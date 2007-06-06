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

module REST

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

	def collection(regex, klass=nil, &block)
		new_rest :Collection, regex.handle_uids, klass, {:regex => regex}, &block
	end

	def model(name, &block)
		new_rest :Model, name, &block
	end

	module Collection
		
		# public, private, index, entity, new, get, edit, delete, find, add, register

		def public
		end

		def private
		end

		def entity 
		end

		def register
		end

		def index
		end

		def entity
		end

		def new
		end

		def get
		end

		def edit
		end

		def delete
		end

		def find
		end

		def add
		end

	end

	module Model
	end

	module Entity
	end
	
end
