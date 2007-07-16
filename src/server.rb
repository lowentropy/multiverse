#! /usr/bin/ruby

$:.unshift File.dirname(__FILE__)

require 'rubygems'
require 'net/http'
require 'mongrel'
require 'debug'
require 'uri'


# The multiverse server. Runs WEBrick.
class Server  < Mongrel::HttpHandler

	include Debug

	def initialize(options={})
		@options = options
		@options[:port] ||= 4000
		@options[:default_lang] ||= :ruby
		@options[:default_env] ||= :host
		@pipes = {}
		@maps = {}
		@environments = {}
		@pipe_threads = []
		@env_replies = []
		@localhost = Host.new(nil, ['localhost', @options[:port]])
	end

	# hook an in-memory environment into this server
	def attach(env, name=@options[:default_env])
		env_in, host_out = IO.pipe
		host_in, env_out = IO.pipe
		env.set_io env_in, env_out
		pipe = MessagePipe.new host_in, host_out
		add_env name, env, pipe
		start_pipe_thread name, pipe
	end

	# add an environment and its pipe. name the env.
	def add_env(name, env, pipe)
		@pipes[name] = pipe
		@environments[name] = env
		env.name = name if env
	end

	# load a script into an environment. start the
	# environment if it doesn't exist yet
	def load(env=@options[:default_env], options={}, *scripts)
		create(env, options) unless @pipes[env]
		scripts.each do |script|
			@pipes[env].write Message.new(:load, @localhost, nil, {:file => script})
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
		add_env name, nil, pipe
		start_pipe_thread name, pipe
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
	def start_pipe_thread(name, pipe)
		@pipe_threads << Thread.new(self, name, pipe) do |server,name,pipe|
			server.pipe_main name, pipe
		end
	end

	# handle a pipe's IO until shutdown
	def pipe_main(name, pipe)
		until @shutdown
			reply = debug "pipe.read" do
				handle_msg name, pipe.read
			end
			pipe.write reply if reply
		end
		pipe.close
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
	def handle_msg(name, msg)
		return unless msg
		case msg.command
		when :no_command, :no_path, :no_action, :ambiguous_path
			msg[:code] = 500
			msg[:body] = msg.to_s
			@env_replies << msg
			nil
		when :get, :put, :post, :delete
			code, body = send msg.command, msg.host, msg.url, msg.params
			Message.new(:reply, msg.host, msg.url, {:code => code, :body => body})
		when :reply
			@env_replies << msg
			nil
		when :map
			map name, msg.params[:regex], msg.params[:handler_id]
		when :log
			env_log name, msg[:message]
		when :error
			env_err name, msg[:message]
		end
	end

	# map a url regex to 
	def map(name, regex, handler_id)
		@maps[regex] = [name, handler_id]
		status = :ok
		Message.new :mapped, @localhost, nil, {:status => status}
	end

	# error from the environment
	def env_err(name, msg)
		puts "ENV ERR: #{name}: #{msg}"
	end

	# log message from the environment
	def env_log(name, msg)
		puts "ENV LOG: #{name}: #{msg}"
	end

	# process HTTP request
	def process(request, response)
		code, body = handle request
		response.start(code) do |head,out|
			#head.merge! reply
			out.write body
		end
	end

	# handle an HTTP request; return code, body
	def handle(request)
		method, url = request_info request
		env, handler_id = handler_for url
		return [404, ''] unless env
		handle_with request, env, handler_id
	end

	# get form params from request
	def request_params(request)
		uri = URI.parse(request.params['REQUEST_URI'])
		params = {}
		uri.query.split('&').each do |str|
			k, v = str.split('=').map {|s| URI.decode(s)}
			params[k] = v
		end
		params
	end

	# handle request with given environment
	def handle_with(request, env, handler_id)
		method, url = request_info request
		params = request_params(request).merge({
			:handler_id => handler_id,
			:method => method})
		msg = Message.new(:action, @localhost, url, params)
		@pipes[env].write msg
		reply = wait_for_reply_to msg
		env_err env, reply[:body] if reply[:code] >= 500
		[reply[:code], reply[:body]]
	end

	# wait for an environment to reply to a request
	def wait_for_reply_to(msg)
		until @shutdown
			@env_replies.each do |reply|
				if reply.id == msg.id
					@env_replies.delete reply
					return reply
				end
			end
			Thread.pass
		end
		{:code => 500, :body => 'server shutdown before reply'}
	end

	# get method and url of request
	def request_info(request)
		[request.params['REQUEST_METHOD'].downcase.to_sym,
		 request.params['REQUEST_PATH']]
	end

	# find the handler for the given url
	def handler_for(url)
		@maps.each do |source,value|
			regex = eval "/#{source}/"
			return [value[0], value[1]] if regex =~ url
		end
		[nil, nil]
	end

	# command requests
	%w(get put post delete).each do |command|
		define_method command do |host,path,*params|
			req = eval "Net::HTTP::#{command.capitalize}.new(path)"
			req.set_form_data(params[0] || {})
			res = Net::HTTP.start(*host.info) {|http| http.request req }
			[res.code.to_i, res.body]
		end
	end

end
