#! /usr/bin/ruby

$:.unshift File.dirname(__FILE__)

require 'rubygems'
require 'net/http'
require 'mongrel'
require 'socket'
require 'config'
require 'debug'
require 'host'
require 'uri'


# The multiverse server. Runs Mongrel.
class Server < Mongrel::HttpHandler

	include Debug
	include Configurable

	attr_reader :localhost

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
			'default_lang' => 'ruby',
			'default_env' => 'host',
			'default_environment_mode' => 'mem')

		@log.debug "port = #{config['port']}"
		@log.debug "log = #{config['log'].inspect}"
		@localhost = Host.new(nil, ['localhost', config['port']])
	end

	# get next available script port
	def next_port
		@env_port += 1
	end

	# hook an in-memory environment into this server
	def attach(env, name=config['default_env'].to_sym)
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

	# create a new environment by some selected mode
	def create(name=config['default_env'].to_sym, options={})
		mode = options[:mode] || config['default_environment_mode']
		send "create_#{mode}", name, options
	end

	# create an environment in a new process attached via socket
	def create_net(name=config['default_env'].to_sym, options={})
		IO.popen(script_command("--port #{@ports[name] ||= next_port}"))
		sleep 0.5
		create_io name, TCPSocket.new('127.0.0.1', @ports[name]), options
	end

	# create an environment that we load and talk to natively (fastest)
	def create_mem(name=config['default_env'].to_sym, options={})
		attach Environment.new, name
	end

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
		command = script_command "| tee out"
		create_io name, IO.popen(command, 'w+'), options
	end

	# create a new environment attached to the given IO pipe
	def create_io(name, io, options={})
		pipe = MessagePipe.new io, io
		add_env name, nil, pipe
		start_pipe_thread name, pipe
	end

	# start the server
	def start
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
				begin
					handle_msg name, pipe.read
				rescue IOError => e
					next
				end
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

	# handle a message from the pipe
	def handle_msg(name, msg)
		return nil if @shutdown
		raise "null message" unless msg

		case msg.command
		# inline error responses
		when :no_command, :no_path, :ambiguous_path
			msg[:code] = 500
			msg[:body] = "#{msg.command.replace(/_/,' ')}: #{msg[:path]}"
			@env_replies << msg

		# 404 error response from environment
		when :not_found
			msg[:code] = 404
			msg[:body] = "not found: #{msg[:path]}"
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
		@log.info "mapped #{regex} to #{name}, id = #{handler_id}"
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

		@log.debug "contacting handler"
		msg = Message.new(:action, @localhost, url, params)
		send_to_pipe @pipes[env], msg
		reply = wait_for_reply_to msg
		if reply[:error]
			[500, reply[:error]]
		else
			env_err env, reply[:body], :error if reply[:code] >= @min_error_code
			[reply[:code], reply[:body]]
		end
	end

	# wait for an environment to reply to a request
	# reply returned must respond to [:code] and [:body]
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
		define_method command do |host,path,*rest|
			debug "server.#{command}" do
				body = rest.shift || ''
				params = rest.shift || {}
				req = eval "Net::HTTP::#{command.capitalize}.new(path)"
				req.body = body if req.request_body_permitted?
				req.set_form_data(params)
				res = Net::HTTP.start(*host.info) {|http| http.request req }
				[res.code.to_i, res.body]
			end
		end
	end

end
