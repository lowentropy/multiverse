#! /usr/bin/ruby

$: << File.dirname(__FILE__)

require 'webrick'
require 'net/http'


# servlet class
class Servlet < WEBrick::HTTPServlet::AbstractServlet
	def initialize(server, mv)
		@server, @mv = server, mv
	end
	def self.get_instance(server, mv)
		mv.servlet server
	end
	def do_GET(req, res)
		@mv.handle_get req, res
	end
	def do_PUT(req, res)
		@mv.handle_put req, res
	end
	def do_POST(req, res)
		@mv.handle_post req, res
	end
end


# The multiverse server. Runs WEBrick.
class Server 

	def initialize(options={})
		@options = options
		@options[:port] ||= 4000
		@options[:default_lang] ||= :ruby
		@options[:default_env] ||= :host
		@environments = {}
		@pipe_threads = []
	end

	# get the singleton servlet instance
	def servlet(server)
		@servlet ||= Servlet.new(server, self)
	end

	# hook an in-memory environment into this server
	def attach(env, name=@options[:default_env])
		env_in, host_out = IO.pipe
		host_in, env_out = IO.pipe
		env.set_io env_in, env_out
		pipe = MessagePipe.new host_in, host_out
		@environments[name] = pipe
		start_pipe_thread pipe
	end

	# load a script into an environment. start the
	# environment if it doesn't exist yet
	def load(env=@options[:default_env], options={}, *scripts)
		create(env, options) unless @environments[env]
		scripts.each do |script|
			@environments[env].write Message.new(:load, nil, script)
		end
	end

	# create an environment in a new process attached via FIFO
	def create(name=@options[:default_env], options={})
		path = File.dirname(__FILE__)
		lang = options[:lang] || @options[:default_lang]
		command = case lang
			when :ruby then "ruby #{path}/ruby-script.rb"
			else raise "unknown script language #{lang}"
		end
		io = IO.popen(command, 'w+')
		pipe = MessagePipe.new io, io
		@environments[name] = pipe
		start_pipe_thread pipe
	end

	# start the server
	def start
		@shutdown = false
		@http = WEBrick::HTTPServer.new @options
		@http.mount '/', Servlet, self
		trap('INT') { @http.shutdown }
		@thread = Thread.new(@http) {|http| http.start}
	end

	# start a handler thread for the given message pipe
	def start_pipe_thread(pipe)
		@pipe_threads << Thread.new(self, pipe) do |server,pipe|
			server.pipe_main pipe
		end
	end

	# handle a pipe's IO until shutdown
	def pipe_main(pipe)
		handle_msg pipe.read until @shutdown
		@pipe.close
	end

	# shut down the server
	def shutdown
		@http.shutdown
		@shutdown = true
	end

	# join w/ the server thread
	def join(timeout=nil)
		@thread.join timeout if @thread
		@pipe_threads.shift.join(timeout) until @pipe_threads.empty?
	end

	# handle a message from the pipe
	def handle_msg(msg)
		case msg.command
		when :no_command
			env_err(msg)
		when :no_path
			env_err(msg)
		when :no_action
			env_err(msg)
		when :ambiguous_path
			env_err(msg)
		when :get
			# TODO
		when :put
			# TODO
		when :post
			# TODO
		when :reply
			@env_replies << msg
		when :map
		end
	end

	# handle a GET request; response body is raw data
	def handle_get(request, response)
		# TODO
	end

	# handle a PUT request; asynchronous message
	def handle_put(request, response)
		# TODO
	end

	# handle a POST request; synchronous function call
	def handle_post(request, response)
		# TODO
	end

	# submit a GET request; blocks and waits for data
	def get(host, path, params={})
		# TODO
		req = Net::HTTP::Get.new(path)
		req.set_form_data params
		res = Net::HTTP.start(*host.info) {|http| http.request req}
		return res.body
	end

	# submit a PUT request; does not block
	def put(host, path, params={})
		# TODO
		req = Net::HTTP::Put.new(path)
		req.set_form_data params
		res = Net::HTTP.start(*host.info {|http| http.request req}
		return nil
	end

	# submit a POST request; blocks and waits for reply message
	def post
		# TODO
		req = Net::HTTP::Post.new(path)
		req.set_form_data params
		res = Net::HTTP.start(*host.info {|http| http.request req}
		return res
	end

end
