#! /usr/bin/ruby

$: << File.dirname(__FILE__)

require 'rubygems'
require 'net/http'
require 'mongrel'


# The multiverse server. Runs WEBrick.
class Server  < Mongrel::HttpHandler

	def initialize(options={})
		@options = options
		@options[:port] ||= 4000
		@options[:default_lang] ||= :ruby
		@options[:default_env] ||= :host
		@environments = {}
		@pipe_threads = []
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
		@http = Mongrel::HttpServer.new '0.0.0.0', @options[:port].to_s
		@http.register "/", self
		@thread = @http.run
		trap('INT') { @http.stop }
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
		@http.stop
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
			data = get msg.host, msg.url, msg.params
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

	# error from the environment
	def env_err(msg)
	end

	# process HTTP request
	def process(request, response)
		reply = {}
		method = request["REQUEST_METHOD"].downcase
		code, body = self.send "handle_#{method}", request, reply
		response.start(code) do |head,out|
			head.merge! reply
			out.write body
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
		req = Net::HTTP::Get.new(path)
		req.set_form_data params
		res = Net::HTTP.start(*host.info) {|http| http.request req}
		return res.code.to_i, res.body
	end

	# submit a PUT request; does not block
	def put(host, path, params={})
		req = Net::HTTP::Put.new(path)
		req.set_form_data params
		res = Net::HTTP.start(*host.info) {|http| http.request req}
		return res.code.to_i
	end

	# submit a POST request; blocks and waits for reply message
	def post
		# TODO
		req = Net::HTTP::Post.new(path)
		req.set_form_data params
		res = Net::HTTP.start(*host.info) {|http| http.request req}
		return res.code, res.body
	end

end
