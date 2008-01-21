$: << File.dirname(__FILE__)

require 'net/http'
require 'uri'

# Extensions to object to include instance_exec
class Object
	
	# Container module for dynamic instance_exec methods
  module InstanceExecHelper; end
  include InstanceExecHelper

	# execute the given code in the context of this object.
	# this allows you to pass arguments to the block.
	# this works by dynamically creating methods on the
	# helper module (which is included in the object).
	def instance_exec(*args, &block)
		begin
			old_c, Thread.critical = Thread.critical, true
			n = 0; n += 1 while respond_to?(name = "__instance_exec#{n}")
			InstanceExecHelper.module_eval do
				define_method(name, &block)
			end
		ensure
			Thread.critical = old_c
		end
		value = send(name, *args)
		InstanceExecHelper.module_eval do
			remove_method name
		end
		value
	end

end

class Fixnum
	def to_hex
		"%x" % [self]
	end
end

# Add basic extensions to String.
class String
	
	# check that we match the uid pattern
	def uid
		raise "invalid uid" unless Regexp::UID =~ self
		self
	end

	# evaluate this string (i.e., treat it as a constant)
	def constantize
		begin
			eval self
		rescue
			nil
		end
	end

	# split a url into parts separated by /
	def url_split
		split('/').reject {|p| p.empty?}
	end

	# find the plural of an english word
	def pluralize
		if self[-1,1] == 'y'
			self[0...-1] + 'ies'
		else
			self + 's'
		end
	end

end


# Adds UID helpers
class Regexp

	# the format of a UID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
	def self.uid_format
		h = '[0-9A-Fa-f]'
		"#{h}{8}-#{h}{4}-#{h}{4}-#{h}{4}-#{h}{12}"
	end

	UID = /#{Regexp.uid_format}/

	# replace instances of {uid} with the uid regex
	def replace_uids
		/#{source.gsub(/\(uid\)/,"(#{Regexp::UID})")}/
	end
end

class Array
	# get self[0..index], and show as path
	def subpath(index=-1)
		'/' + self[0..index].join('/')
	end
end

%w(Get Put Post Delete).each do |verb|
	class << "Net::HTTP::#{verb}".constantize
		def body?
			self::REQUEST_HAS_BODY
		end
	end
end

class Hash
	def url_encode
		'?' + map do |k,v|
			URI.encode(k.to_s) + '=' + URI.encode(v.to_s)
		end.join('&')
	end
end
