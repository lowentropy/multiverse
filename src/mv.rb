module MV

	class ThreadLocal
		def initialize
			@threads = {}
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
	end

	%w(get put post delete).each do |verb|
		self.send :define_method, verb do |*args|
			$server.send_request verb, *args
		end
	end

	def self.log(level, message)
		puts "#{level}: #{message}" # DEBUG
		server.log script, level, message
	end

	def self.map(regex, &block)
		(@routes ||= {})[id = UID.random] = block
		server.map script, id, regex
	end

	def self.unmap(id)
		(@routes ||= {}).delete id
		server.unmap id
	end

	def self.load(*scripts)
		server.load *scripts
	end

	def self.require(*files)
		server.require script, *files
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
