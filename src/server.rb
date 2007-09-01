#! /usr/bin/ruby

$:.unshift File.dirname(__FILE__)

require 'rubygems'
require 'net/http'
require 'mongrel'
require 'config'
require 'debug'
require 'uri'


# The multiverse server. Runs Mongrel.
class Server < Mongrel::HttpHandler

	include Debug
	include Configurable

	def initialize(options={})
		@pipes = {}
		@maps = {}
		@environments = {}
		@pipe_threads = []
		@env_replies = []
		@min_error_code = 400

		Configurable.base = File.expand_path(File.dirname(__FILE__) + '/../config')
		config_file 'host.config', 'host'
		config_options options
		config_default(
			:port => 4000,
			:default_lang => :ruby,
			:default_env => :host)

		config_log

		@localhost = Host.new(nil, ['localhost', config[:port]])
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
			send_to_pipe @pipes[env], Message.new(:load, @localhost, nil, {:file => script})
		end
	end

	# create an environment in a new process attached via FIFO
	def create(name=@options[:default_env], options={})
		path = File.dirname(__FILE__)
		lang = options[:lang] || config[:default_lang]
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
		@pipes.values.each {|pipe| send_to_pipe pipe, Message.system(:start)}
		@http = Mongrel::HttpServer.new '0.0.0.0', config[:port].to_s
		@http.register "/", self
		@thread = @http.run
		trap('INT') do
			@log.warn "interrupted: shutting down"
			shutdown
			join 0.5
		end
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
			send_to_pipe pipe, reply if reply
			Thread.pass unless @shutdown
		end
		pipe.close
	end

	# shut down the server
	def shutdown
		@http.stop if @http
		@environments.keys.each do |env|
			@log.debug "sending quit to #{env}"
			send_to_pipe @pipes[env], Message.system(:quit, :timeout => 1)
		end
		@shutdown = true
	end

	# join w/ the server thread
	def join(timeout=nil)
		until @pipe_threads.empty?
			thread = @pipe_threads.shift
			thread.join timeout if thread
		end
		@thread.join timeout if @thread
	end

	# handle a message from the pipe
	def handle_msg(name, msg)
		return nil if @shutdown
		raise "null message" unless msg

		case msg.command
		# inline error responses
		when :no_command, :no_path, :ambiguous_path
			msg[:code] = 500
			msg[:body] = msg.to_s
			@env_replies << msg

		# 404 error response from environment
		when :not_found
			msg[:code] = 404
			msg[:body] = "not found: #{msg.url}"
			@env_replies << msg

		# requests to other hosts are handled inline
		when :get, :put, :post, :delete
			code, body = send msg.command, msg.host, msg.url, msg.params
			return Message.new(:reply, msg.host, msg.url, {:code => code, :body => body})

		# replies are handled by another thread
		when :reply
			@env_replies << msg

		# script url map command
		when :map
			map name, msg.params[:regex], msg.params[:handler_id]

		# out-of-band bookkeeping
		when :log, :error
			send "env_#{msg.command}", name, msg[:message]

		# status messages
		when :started, :quit
			env_log name, "environment #{msg.command}"
		end

		nil
	end

	# map a url regex to an environment handler id
	def map(name, regex, handler_id)
		# FIXME: there should be scope restrictions for security
		@maps[regex] = [name, handler_id]
		Message.new :mapped, @localhost, nil, {:status => :ok}
	end

	# error from the environment
	def env_err(name, msg)
		@log.error "#{name}: #{msg}"
	end
	alias :env_error :env_err

	# log message from the environment
	def env_log(name, msg)
		@log.info "#{name}: #{msg}"
	end

	# process HTTP request
	def process(request, response)
		debug 'server.process' do
			begin
				code, body = handle request
			rescue Exception => e
				@log.error e
				code, body = 500, e.message
			end
			response.start(code) do |head,out|
				out.write body
			end
		end
	end

	# send a message through a local pipe
	def send_to_pipe(pipe, message)
		pipe.write message
	end

	# handle an HTTP request; return code, body
	def handle(request)
		debug 'handle' do
			info = request_info request
			method, url = info[:method], info[:path]
			env, handler_id = handler_for url
			return [404, "#{method} #{url}"] unless env
			handle_with request, env, handler_id
		end
	end

	# get form params from request
	def request_params(request)
		uri = URI.parse(request.params['REQUEST_URI'])
		params = {}
		return (params = {}) unless uri.query
		uri.query.split('&').each do |str|
			next unless str
			k, v = str.split('=').map {|s| URI.decode(s)}
			params[k] = v
		end
		params
	end

	# handle request with given environment
	def handle_with(request, env, handler_id)
		@log.debug "finding handler"
		info = request_info request
		method, url = info[:method], info[:path]
		params = request_params(request).merge({
			:handler_id => handler_id,
			:method => method})

		@log.debug "contacting handle"
		msg = Message.new(:action, @localhost, url, params)
		send_to_pipe @pipes[env], msg
		reply = wait_for_reply_to msg
		env_err env, reply[:body] if reply[:code] >= @min_error_code
		[reply[:code], reply[:body]]
	end

	# wait for an environment to reply to a request
	# reply returned must respond to [:code] and [:body]
	def wait_for_reply_to(msg)
		@log.debug "waiting for reply"
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
		{	:method	=> request.params['REQUEST_METHOD'].downcase.to_sym,
			:path		=> URI.parse(request.params['REQUEST_PATH']),
			:body		=> request.body, # FIXME: ???
			:params	=> request_params(request) }
	end

	# find the handler for the given url
	def handler_for(url)
		@maps.each do |source,value|
			regex = eval "/#{source}/"
			return [value[0], value[1]] if regex =~ url.path
		end
		[nil, nil]
	end

	# command requests
	%w(get put post delete).each do |command|
		define_method command do |host,path,*params|
			debug "server.#{command}" do
				req = eval "Net::HTTP::#{command.capitalize}.new(path)"
				req.set_form_data(params[0] || {})
				res = Net::HTTP.start(*host.info) {|http| http.request req }
				[res.code.to_i, res.body]
			end
		end
	end

end
