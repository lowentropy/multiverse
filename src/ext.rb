class Object

  module InstanceExecHelper; end
  include InstanceExecHelper

  def instance_exec(*args, &block)
		begin
			old_c, Thread.critical = Thread.critical, true
			n = 0; n += 1 while respond_to?(name = "__instance_exec#{n}")
			InstanceExecHelper.module_eval{ define_method(name, &block) }
		ensure
			Thread.critical = old_c
		end
		begin
			return send(name, *args)
		ensure
			InstanceExecHelper.module_eval{ remove_method(name) }
		end
	end
end
#
# This code is to prevent DOS attacks by hiding some
# builtin methods of Ruby's Thread class:
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

	# store the old critical= method into a hidden wrapper
	@@crit = CritContainer.new(method(:critical=))

	# redefine critical= to use the safe wrapper
	def self.critical=(*args)
		@@crit.set *args
	end

	# don't allow any access to abort_on_exception=
	def self.abort_on_exception=(*args)
		raise "somebody's trying to be naughty!"
	end
	def abort_on_exception=(*args)
		raise "somebody's trying to be naughty!"
	end
end

class String
	def constantize
		begin
			eval self
		rescue
			nil
		end
	end
	def pluralize
		if self[-1,1] == 'y'
			self[0...-1] + 'ies'
		else
			self + 's'
		end
	end
end

class Regex
	def uid_format
		h = '[0-9A-Fa-f]'
		"#{h}{8}-#{h}{4}-#{h}{4}-#{h}{4}-#{h}{12}"
	end
	def replace_uids
		/#{source.gsub(/\{uid\}/,uid_format)}/
	end
end

class Hash
	def to_stream
		inspect
	end
end
