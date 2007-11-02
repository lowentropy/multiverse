require 'net/http'
require 'uri'

# Extensions to object to include instance_exec
class Object

	@@define_iec = proc do |block|
		begin
			old_c, Thread.critical = Thread.critical, true
			n = 0; n += 1 while respond_to?(name = "__instance_exec#{n}")
			InstanceExecHelper.module_eval { define_method(name, &block) }
			return name
		ensure
			Thread.critical = old_c
		end
	end

	@@undefine_iec = proc do |name|
		InstanceExecHelper.module_eval { remove_method(name) }
	end

	# Container module for dynamic instance_exec methods
  module InstanceExecHelper; end
  include InstanceExecHelper

	# execute the given code in the context of this object.
	# this allows you to pass arguments to the block.
	# this works by dynamically creating methods on the
	# helper module (which is included in the object).
  def instance_exec(*args, &block)
		name = @@define_iec.call block
		value = send(name, *args)
		@@undefine_iec.call name
		value
	end
end

# This code is to prevent DOS attacks by hiding some
# builtin methods of Ruby's Thread class,
# critical= and abort_on_exception=.
class Thread

	# this inner class allows code running at $SAFE==0
	# to access critical=.
	class CritContainer
		def initialize(crit)
			@crit = crit
		end
		def set(*args)
			raise "safe threads can't go critical" if $SAFE > 0
			@crit.call *args
		end
		def instance_variable_get(*args)
			raise "somebody's trying to be naughty!"
		end
	end

	unless respond_to? :old_crit=
		class << self
			alias :old_crit= :critical=
		end
	end

	# store the old critical= method into a hidden wrapper
	@@crit = CritContainer.new(method(:old_crit=))

	# redefine critical= to use the safe wrapper
	def self.critical=(*args)
		@@crit.set *args
	end

	# don't allow any access to abort_on_exception=
	def self.abort_on_exception=(*args)
		raise "somebody's trying to be naughty!"
	end
			
	# don't allow any access to abort_on_exception=
	def abort_on_exception=(*args)
		raise "somebody's trying to be naughty!"
	end
end

# Add basic extensions to String.
class String
	
	# evaluate this string (i.e., treat it as a constant)
	def constantize
		begin
			eval self
		rescue
			nil
		end
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
	def uid_format
		h = '[0-9A-Fa-f]'
		"#{h}{8}-#{h}{4}-#{h}{4}-#{h}{4}-#{h}{12}"
	end

	# replace instances of {uid} with the uid regex
	def replace_uids
		/#{source.gsub(/\{uid\}/,uid_format)}/
	end

	# like match, but returns nil unless the matching text
	# is the same length as the input string
	def match_all?(str)
		return nil unless (m = match str)
		m[0].size == str.size ? m : nil
	end
end

class Array
	# get self[0..index], and show as path
	def subpath(index=-1)
		'/' + self[0..index].join('/')
	end
	def inject_with_index(value=0, &block)
		each_with_index do |x,i|
			value = yield value, x, i
		end
		value
	end
	def without(i)
		self[0,i] + self[i+1..-1]
	end
	def permute
		return self if empty?
		return [self] if size == 1
		inject_with_index([]) do |a,x,i|
			a + without(i).permute.map {|p| [x,*p]}
		end
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
