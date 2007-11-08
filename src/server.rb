#! /usr/bin/ruby

$:.unshift File.dirname(__FILE__)

require 'rubygems'
require 'net/http'
require 'mongrel'
require 'socket'
require 'config'
require 'debug'
require 'agent'
require 'host'
require 'uri'
require 'ext'

include Net

# The multiverse server. Runs Mongrel.
class Server < Mongrel::HttpHandler

	include Debug
	include Configurable

	attr_reader :localhost

	# set up server state and load configuration.
	def initialize(options={})
		@pipes = {}
		@maps = {}
		@ports = {}
		@env_port = 4000
		@environments = {}
		@pipe_threads = []
		@env_replies = []
		@min_error_code = 500

		Configurable.base = File.expand_path(File.dirname(__FILE__) + '/../config')
		config_file 'host.config', 'host'
		config_log config['address'], options[:log]
		config_options options
		config_default(
			'port' => 4000,
			'wait_timeout' => 5.0,
			'default_lang' => 'ruby',
			'default_env' => 'host',
			'default_environment_mode' => 'mem')

		@log.debug "port = #{config['port']}"
		@log.debug "log = #{config['log'].inspect}"
		@localhost = Host.new(nil, ['localhost', config['port']])
	end

	# load a script into an environment. start the
	# environment if it doesn't exist yet. this
	# function will block until an error occurs or
	# the scripts are loaded
	def load(env=config['default_env'].to_sym, options={}, *scripts)
		unless @pipes[env]
			@log.debug "creating new env #{env}"
			create(env, options)
			@log.debug "created env #{env}"
		end
		scripts.each do |script|
			@log.debug "attempting to load #{script}"
			load_msg = Message.system(:load, :file => script)
			send_to_pipe @pipes[env], load_msg
			reply = wait_for_reply_to load_msg
			@log.debug "loaded #{script}"
			raise reply[:error] if reply[:error]
		end
	end

	# start the server; also trap user interrupts.
	def start(pad=true)
		sleep 0.5 if pad
		@shutdown = false
		@pipes.values.each {|pipe| send_to_pipe pipe, Message.system(:start)}
		@http = Mongrel::HttpServer.new '0.0.0.0', config['port'].to_s
		@http.register "/", self
		@thread = @http.run
		trap('INT') do
			@log.fatal "interrupted: shutting down"
			shutdown
			join 0.5
		end
		sleep 0.5 if pad
	end

	# shut down the server
	def shutdown
		@http.stop if @http
		@environments.keys.each do |env|
			next unless @pipes[env]
			@log.debug "sending quit to #{env}"
			send_to_pipe @pipes[env], Message.system(:quit, :timeout => 1)
		end
		@log.info "waiting for environments to complete"
		while @environments.any?
			@log.debug "remaining environments: #{@environments.keys.inspect}"
			sleep 1
		end
		@log.info "all environments now complete"
		@shutdown = true
	end

	# join w/ the server thread
	def join(timeout=nil)
		until @pipe_threads.empty?
			@log.debug "waiting for pipe thread..."
			thread = @pipe_threads.shift
			thread.join timeout if thread
			@log.debug "pipe thread done."
		end
		@log.debug "waiting for main thread..."
		@thread.join timeout if @thread
		@log.debug "main thread done."
	end

	# issue an external GET request
  def get(*params)
    handle_request :get, *params
  end

	# issue an external PUT request
  def put(*params)
    handle_request :put, *params
  end

	# issue an external POST request
  def post(*params)
    handle_request :post, *params
  end

	# issue an external DELETE request
  def delete(*params)
    handle_request :delete, *params
  end

	# process HTTP request.
	# THIS MUST BE PUBLIC because it is called from Mongrel.
	# TODO add a public wrapper that checks the caller
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

	private

	# handle a pipe's IO until shutdown
	def pipe_main(name, pipe)
		begin
			until @shutdown
				break if pipe.closed?
				next unless (msg = next_message(pipe))
				start_handler name, pipe, msg
				Thread.pass unless @shutdown
			end
			pipe.close
		rescue Exception => e
			@log.fatal e
			shutdown
			join 0
		end
	end

	# read the next message from the input stream
	def next_message(pipe)
		begin
			pipe.read
		rescue IOError => e
			@log.info "pipe closed"
			return nil
		end
	end
	
	# start a handler thread for a received message
	def start_handler(name, pipe, msg)
		Thread.new(self,msg) do |srv,msg|
			reply = begin
				srv.send :handle_msg, name, msg
			rescue Exception => e
				Message.system(:reply, :error => e.message)
			end
			srv.send :send_to_pipe, pipe, reply if reply
		end
	end


	# issue an HTTP request. this function will block until some
	# respose is received. returns [code, body].
  def handle_request (verb, host, path, *rest)
		body, params = (rest.shift || ''), (rest.shift || {})
		encoded = params.map {|k,v| "#{k}=#{v}"}.join("&")
		request = create_request(verb, path, body, params)
		response = Net::HTTP.start(*host.info) do |http|
			http.request request
		end
		[response.code.to_i, response.body]
  end

	# create a properly-constructed request
	def create_request(verb, path, body, params)
		request_class = "HTTP::#{verb.to_s.capitalize}".constantize
		if body and request_class.body?
			request = request_class.new(path + params.url_encode)
			request.body = body
		else
			request = request_class.new path
			request.form_data = params
		end
		request
	end

	# get next available script port
	def next_port
		@env_port += 1
	end

	# add an environment and its pipe. name the env.
	def add_env(name, env, pipe)
		@pipes[name] = pipe
		@environments[name] = env
		env.name = name if env
	end

	public

	# create a new environment by some selected mode
	def create(name=config['default_env'].to_sym, options={})
		mode = options[:mode] || config['default_environment_mode']
		send "create_#{mode}", name, options
	end

	private

	# create an environment in a new process attached via socket
	def create_net(name=config['default_env'].to_sym, options={})
		IO.popen(script_command("--port #{@ports[name] ||= next_port}"))
		sleep 0.5
		create_io name, TCPSocket.new('127.0.0.1', @ports[name]), options
	end

	# create an environment that we load and talk to natively (fastest)
	def create_mem(name=config['default_env'].to_sym, options={})
		attach Environment.new(nil, nil, true), name
	end

	public

	# hook an in-memory environment into this server
	def attach(env, name=config['default_env'].to_sym)
		in_buf, out_buf = Buffer.new, Buffer.new
		pipe = MemoryPipe.new in_buf, out_buf
		pipe.debug = env.instance_variable_get :@superfatal
		env.set_io out_buf, in_buf, 'MemoryPipe'
		add_env name, env, pipe
		start_pipe_thread name, pipe
	end

	private

	# get the command for running a script
	def script_command(arguments="", options={})
		path = File.dirname(__FILE__)
		lang = options[:lang] || config['default_lang'].to_sym
		command = case lang
			when :ruby then "ruby #{path}/ruby-script.rb #{arguments}"
			else raise "unknown script language #{lang}"
		end
	end

	# create an environment in a new process attached via FIFO
	def create_fifo(name=config['default_env'].to_sym, options={})
		command = script_command "| tee .out"
		create_io name, IO.popen(command, 'w+'), options
	end

	# create a new environment attached to the given IO pipe
	def create_io(name, io, options={})
		pipe = MessagePipe.new io, io
		add_env name, nil, pipe
		start_pipe_thread name, pipe
	end

	# load a software agent
	def load_agent(agent)
		@log.info "got request to load agent: #{agent.to_yaml}"
	end

	# start a handler thread for the given message pipe
	def start_pipe_thread(name, pipe)
		@pipe_threads << Thread.new(self, name, pipe) do |server,name,pipe|
			server.send :pipe_main, name, pipe
		end
	end

	# handle a message from the pipe
	def handle_msg(name, msg)
		return nil if @shutdown
		return nil unless msg

		case msg.command
		# inline error responses
		when :no_command, :no_path, :ambiguous_path
			msg[:code] = 500
			msg[:error] = "#{msg.command.to_s.gsub(/_/,' ')}: #{msg[:path]}"
			@log.debug "#{msg[:error]} #{msg.params.inspect}"
			@env_replies << msg

		# load a software agent
		when :load_agent
			load_agent YAML.load(msg[:agent])

		# 404 error response from environment
		when :not_found
			msg[:code] = 404
			msg[:body] = "not found: #{msg[:path]}"
			@log.debug "#{msg[:error]} #{msg.params.inspect}"
			@env_replies << msg

		# requests to other hosts are handled inline
		when :get, :put, :post, :delete
			host = msg.host.host ? msg.host : @localhost
			code, body = send msg.command, host, msg.url, msg.params.delete(:body), msg.params
			return Message.new(:reply, msg.host, msg.url, {:code => code, :body => body, :message_id => msg[:message_id]})

		# replies are handled by another thread
		when :reply, :loaded
			@env_replies << msg

		# script url map command
		when :map
			return map(name, msg.params[:regex], msg.params[:handler_id])

		# out-of-band bookkeeping
		when :log, :error
			level = msg[:level] || :info
			send "env_#{msg.command}", name, msg[:message], level
			@env_replies << msg

		# status messages
		when :started, :quit
			env_log name, "environment #{msg.command}: #{msg[:message]}"
			remove_env name if msg.command == :quit
		end

		nil
	rescue Exception => e
		@log.fatal e
		fail
	end

	# remove the env from active status
	def remove_env(name)
		@environments.delete name
		@pipes.delete(name).close
	end

	# map a url regex to an environment handler id
	def map(name, regex, handler_id)
		# FIXME: there should be scope restrictions for security
		@maps[regex] = [name, handler_id]
		@log.info "mapped #{regex.source} to #{name}, id = #{handler_id}"
		Message.system(:mapped, :status => :ok)
	end

	# error from the environment
	def env_err(name, msg, level)
		@log.send level, "#{name}: #{msg}"
	end
	alias :env_error :env_err

	# log message from the environment
	def env_log(name, msg, level=:info)
		@log.send level.to_s, "#{name}: #{msg}"
	end

	# send a message through a local pipe
	def send_to_pipe(pipe, message)
		return unless pipe
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

	# get information about the request
	def request_info(request)
		body = read_body(request.body)
		{	:method	=> request.params['REQUEST_METHOD'].downcase.to_sym,
			:path		=> URI.parse(request.params['REQUEST_PATH']),
			:body		=> body,
			:params	=> request_params(request, body) }
	end

	# read the body from a mongrel request
	def read_body(body)
		if body.kind_of? StringIO
			body.string
		else
			body.read
		end
	end

	# get form params from request
	def request_params(request, body)
		to_decode =
			if /encoded/ =~ request.params['Content-Type']
				body
			else
				uri = request.params['REQUEST_URI']
				uri[(uri.rindex('?')||-2)+1..-1]
			end

		params = {}
		to_decode.split('&').each do |pair|
			key, val = pair.split('=').map {|s| URI.decode(s)}
			params[key] = val
		end

		params
	end

	# handle request with given environment
	def handle_with(request, env, handler_id)
		info = request_info request
		method, url = info[:method], info[:path]
		params = request_params(request, info[:body]).merge({
			:handler_id => handler_id,
			:method => method,
			:body => info[:body]})#.stringify!

		@log.debug "calling #{env}'s handler for #{url}"
		msg = Message.new(:action, @localhost, url, params)
		send_to_pipe @pipes[env], msg
		reply = wait_for_reply_to msg
		# FIXME: i don't like this inconsistency
		if reply[:error]
			reply[:code] = 500
			reply[:body] = reply[:error]
		end
		env_err env, reply[:body], :error if reply[:code] >= @min_error_code
		[reply[:code], reply[:body]]
	end

	# check if a request has taken too long
	def timed_out?(time)
		(Time.now - time) > config['wait_timeout']
	end

	# wait for an environment to reply to a request
	# reply returned must respond to [:code] and [:body]
	def wait_for_reply_to(msg)
		begin
			start_time = Time.now
			until @shutdown or timed_out?(start_time)
				@env_replies.each do |reply|
					if reply.id == msg.id
						@env_replies.delete reply
						return reply
					end
				end
				Thread.pass
			end
		rescue Exception => e
			return {:code => 500, :body => "unexpected error: #{e}"}
		end
		if @shutdown
			return {:code => 500, :body => "server shutdown before reply"}
		else
			return {:code => 500, :body => "timed out: #{msg}"}
		end
	end

	
	# find the handler for the given url
	def handler_for(url)
		@maps.each do |regex,value|
			if regex.match_all? url.path.split('/')[1]
				@log.debug "#{url} maps to #{value[0]} via #{regex}"
				return [value[0], value[1]] 
			end
		end
		[nil, nil]
	end

end
