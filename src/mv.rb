module MV

	private

	def self.def_priv(name, &block)
		module_eval %{
			@#{name} = block
			def self.#{name}(*args,&block)
				@#{name}.call *args, &block
			end
		}
	end

	class ThreadLocal
		def initialize
			@threads = {}.taint
		end
		def [](name)
			thread[name]
		end
		def []=(name, value)
			thread[name] = value
		end
		def thread
			@threads[MV.thread_id] ||= {}
		end
		def continue(old_id)
			thread.merge! @threads[old_id]
			nil
		end
	end
		
	def self.__continue(old_id)
		$thread.continue(old_id)
	end

	%w(get put post delete).each do |verb|
		self.def_priv verb do |*args|
			server.send_request verb, *args
		end
	end

	def_priv :log do |level,message|
		#puts "#{level}: #{message}" # DEBUG
		threads = $thread.instance_variable_get(:@threads)
		#raise "real: #{thread_id}, stored: #{threads.keys[0]}"
		#raise threads.values[0].keys.inspect
		man = threads.values[0][:server]
		#raise "MV.log [thread_id] = #{thread_id}"
		server.log script, level, message
		nil
	end

	def_priv :map do |regex,block|
		(@routes ||= {})[id = UID.random] = block
		server.map script, id, regex
		nil
	end

	def_priv :unmap do |id|
		(@routes ||= {}).delete id
		server.unmap id
		nil
	end

	def_priv :load do |*scripts|
		server.load *scripts
		nil
	end

	def_priv :require do |*files|
		server.require script, *files
		nil
	end

	private

	def self.script
		$thread[:script]
	end

	def self.server
		$thread[:server]
	end

	def self.action(id, request)
		raise 'illegal route' unless @routes[id]
		@routes[id].call request
	end

	def self.thread_id
		Thread.current.object_id
	end

end
