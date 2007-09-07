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

	%w(public private).each do |mode|
		eval "@visibility = :#{mode}"
	end


	class RestError < RuntimeError
		attr_reader :code, :body
		def initialize(code, body)
			@code, @body = code, body
			super("#{code}: #{body}")
		end
	end


	def entity(regex, klass, &block)
		(@entities ||= []) << [(@visibility||:public), Entity.new(klass, regex, &block)]
	end

	def store(regex, klass, &block)
		(@stores ||= []) << [(@visibility||:public), Store.new(klass, regex, &block)]
	end

	def behavior(regex, &block)
		(@behaviors ||= []) << [(@visibility||:public), Behavior.new(regex, &block)]
	end

end
