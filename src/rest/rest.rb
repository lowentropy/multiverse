$: << File.expand_path(File.dirname(__FILE__))

module REST
	class Adapter
		def initialize(url)
			@uri = URI.parse(url)
		end
	end
end

require 'ext'
require 'pattern'
require 'store'
require 'entity'
require 'behavior'


# RESTful extensions
class String
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
		attr_reader :code, :body
		def initialize(code, body)
			@code, @body = code, body
			super("#{code}: #{body}")
		end
	end

	# toplevel entity
	def entity(regex, klass, &block)
		(@entities ||= []) << [(@visibility||:public), Entity.new(klass, regex, &block)]
	end

	# toplevel store
	def store(regex, klass, &block)
		(@stores ||= []) << [(@visibility||:public), Store.new(klass, regex, &block)]
	end

	# toplevel behavior
	def behavior(regex, &block)
		(@behaviors ||= []) << [(@visibility||:public), Behavior.new(regex, &block)]
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
