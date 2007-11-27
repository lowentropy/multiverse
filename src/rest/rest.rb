module REST
	class Adapter
	  attr_reader :uri
		def initialize(url)
			@uri = URI.parse(url)
		end
	  def env
	    $env
    end
		def get
			code, body = $env.get @uri.to_s, '', {}
			raise RestError.new(code, body) if code != 200
			YAML.load body
		end
		def put(body='', params={})
			code, body = $env.put @uri.to_s, body, params
			raise RestError.new(code, body) if code != 200
		end
		alias :set :put
		def post(body='', params={})
			code, body = $env.post @uri.to_s, body, params
			raise RestError.new(code, body) if code != 200
			YAML.load body
		end
		def delete
			code, body = $env.delete @uri.to_s, '', {}
			raise RestError.new(code, body) if code != 200
		end
		# a no-argument missing method call should refer
		# to some kind of sub-instance
		def method_missing(id, *args)
			return super if args.any?
			return "#{uri}/#{id.id2name}".to_rest
		end
	end
end

require 'ext'
require 'rest/pattern'
require 'rest/store'
require 'rest/entity'
require 'rest/behavior'


# RESTful extensions
class String
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
		attr_reader :code, :body
		def initialize(code, body)
			@code, @body = code, body
			super("#{code}: #{body}")
		end
	end

	# toplevel entity
	def entity(regex, klass=nil, &block)
		(@entities ||= []) << [(@visibility||:public), Entity.new(klass, regex, &block)]
	end

	# toplevel store
	def store(regex, klass=nil, &block)
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
