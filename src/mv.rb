$: << File.dirname(__FILE__)
require 'uid'

module MV

	class Request
		attr_reader :body, :params, :headers
		def initialize(body, params, headers)
			@body, @params, @headers = body, params, headers
		end
	end

	class Response
		attr_reader :code, :body, :headers
		def initialize(code, body, headers)
			@code, @body, @headers = code, body, headers
		end
	end

	private

	def self.def_priv(name, return_nil=true, &block)
		module_eval %{
			@#{name} = block
			def self.#{name}(*args,&block)
				result = @#{name}.call *args, &block
				#{return_nil} ? nil : result
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
		self.def_priv verb, false do |options|
			code, body, headers = server.send_request verb, options
			Response.new code, body, headers
		end
	end

	def_priv :sym, false do |str|
		raise "naughty!" unless /[a-zA-Z0-9_]+/ =~ str
		str.to_sym
	end

	def_priv :log do |level,message|
		threads = $thread.instance_variable_get(:@threads)
		man = threads.values[0][:server]
		server.log script, level, message
	end

	def_priv :_map do |regex,block|
		routes[id = UID.random] = block
		server.map script, id, regex
	end

	def_priv :unmap do |id|
		routes.delete id
		server.unmap id
	end

	def_priv :load do |name,*scripts|
		server.load name, *scripts
	end

	def_priv :pass do
		Thread.pass
	end

	def_priv :req do |*files|
		server.req script, *files
	end

	def self.map(regex, block)
		_map regex, block
	end

	private

	def self.script
		$thread[:script]
	end

	def self.server
		$thread[:server]
	end

	def self.routes
		script.routes
	end


	def self.action(id, body, params, headers)
		raise "illegal route" unless routes[id]
		request = Request.new body, params, headers
		routes[id].call request
	end

	def self.thread_id
		Thread.current.object_id
	end

end
