class Object
  module InstanceExecHelper; end
  include InstanceExecHelper
  def instance_exec(*args, &block)
    begin
      old_critical, Thread.critical = Thread.critical, true
      n = 0
      n += 1 while respond_to?(mname="__instance_exec#{n}")
      InstanceExecHelper.module_eval{ define_method(mname, &block) }
    ensure
      Thread.critical = old_critical
    end
    begin
      ret = send(mname, *args)
    ensure
      InstanceExecHelper.module_eval{ remove_method(mname) } rescue nil
    end
    ret
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
	def replace_uids
		/#{source.gsub(/\{uid\}/,'[0-9a-fA-F]{16}')}/
	end
end

class Hash
	def to_stream
		inspect
	end
end


