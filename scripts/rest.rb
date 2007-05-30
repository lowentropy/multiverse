class String
	def constantize
		begin
			eval self
		rescue
			self
		end
	end
end

module REST

	def new_rest(pattern, name, klass=nil, &block)
		name = name.to_s.capitalize
		klass ||= name.constantize || Class.new
		klass.extend eval("rest.#{pattern}")
		klass.instance_eval {@name = name.to_s}
		klass.instance_eval &block
		klass.register
	end

	def collection(regex, klass)
	end

end
