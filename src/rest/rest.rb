$: << File.expand_path(File.dirname(__FILE__))

require 'ext'
require 'pattern'
require 'store'
require 'entity'
require 'behavior'

# RESTful service patterns
module REST

	%w(public private).each do |mode|
		eval "@visibility = :#{mode}"
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
