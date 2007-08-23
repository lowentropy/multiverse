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
			return send name, *args
		ensure
			InstanceExecHelper.module_eval{ remove_method(name) }
		end
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


