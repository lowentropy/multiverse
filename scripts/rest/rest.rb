# RESTful extensions
class ::String
	def to_rest
		REST::Adapter.new(self)
	end
	def to_entity
		REST::EntityAdapter.new(self)
	end
	def to_store
		REST::StoreAdapter.new(self)
	end
	def to_behavior
		REST::BehaviorAdapter.new(self)
	end
end

# RESTful service patterns
module REST
  
	# set toplevel visibility
  def public
    @visibility = :public
  end

	# set toplevel visibility
  def private
    @visibility = :private
  end

	class RestError < RuntimeError
		def initialize(reply)
			@reply
			super("#{code}: #{body}")
		end
		%w(code body headers).each do |fun|
			define_method MV.sym(fun) do
				@reply.send fun
			end
		end
	end

	# toplevel entity
	def entity(regex, klass=nil, &block)
		entity = Entity.new(klass, regex, &block)
		(@entities ||= []) << [(@visibility||:public), entity]
		entity
	end

	# toplevel store
	def store(regex, klass=nil, &block)
		store = Store.new(klass, regex, &block)
		(@stores ||= []) << [(@visibility||:public), store]
		store
	end

	# toplevel behavior
	def behavior(regex, &block)
		behavior = Behavior.new(regex, &block) 
		(@behaviors ||= []) << [(@visibility||:public), behavior]
		behavior
	end

	# map REST handlers to MV handlers
	def map_rest
		@entities ||= []
		@stores ||= []
		@behaviors ||= []
		(@entities + @stores + @behaviors).each do |mapping|
			# FIXME: make visibility a property of the pattern
			vis, pattern = mapping
			pattern.map
		end
	end

end
