$: << File.dirname(__FILE__)

require 'thread'
require 'sandbox'
require 'pipe'
require 'host'
require 'untrace'
require 'rest/rest'
require 'agent'
require 'uri'
require 'ext'


# Script environment handles states, functions, classes,
# messaging, url mapping, sandboxing, and security.
# It is a sexy beast.
#
# TODO do refactoring as per comments
# TODO group functions in some sane way
# TODO export function sets to mixins
class Environment

	attr_accessor :name, :sandbox_check
	attr_reader :local_set

	# set up all the variables and start the I/O threads
	def initialize(input=$stdin, output=$stdout, in_memory=false)
		create_localizers
		@pipe = MessagePipe.new input, output unless in_memory
		@included = []
		@inbox = []
		@replies = []
		@sandbox = Sandbox.new
		@sandbox.extend REST
		@mutex = Mutex.new
		@state = [:global].taint
		@classes = {}.taint
		@functions = {}.taint
		@start = false
		@required = [].taint
		@agents = {}.taint
		@states = [].taint
		@outbox = [].taint
		@url_patterns = {}.taint
		@listeners = {}.taint
		@handlers = {}.taint
		@in_memory = in_memory
		@quit_sent = false
		@superfatal = false
		@sandbox_check = true
		state(:global) {}
		start_io_threads
		add_script_commands
		add_script_variables
	end

	# accessor for thread-local storage
	def [](name)
		@local_get.call name
	end

	# accessor for thread-local storage
	def []=(name, value)
		if name.to_s == 'sandbox_id' and $SAFE > 0
			raise "can't swap sandboxes" 
		end
		@local_set.call name => value
	end

	private

	# create procs which are at $SAFE=0 than get and set
	# any instance variables on the current thread that
	# are of the form @_mv_XXX
	def create_localizers
		@local_set = proc do |args|
			args.each do |name,value|
				raise "naughty!" unless /[a-zA-Z_]+/ === name.to_s
				Thread.current.instance_variable_set "@_mv_#{name}", value
			end
		end
		@local_get = proc do |name|
			raise "naughty!" unless /[a-zA-Z_]+/ === name.to_s
			Thread.current.instance_variable_get "@_mv_#{name}"
		end
	end

	public

	# reset the input/output pipes
	def set_io(input, output, type='MessagePipe')
		@pipe = type.constantize.new input, output
	end

	# let threads outside the default sandbox access our functions
	# through $env.
	def externalize_sandbox
		@sandbox.chooser
	end

	private

	# start IO processing threads
	def start_io_threads
		@pipe_thread = Thread.new(self) do |env|
			env.send :pipe_main
		end
		@io_thread = Thread.new(self) do |env|
			env.send :io_main
		end
	end

	# add script-accessible (unsafe) functions
	def add_script_commands
		%w(	map current_state req << [] []=
				require k goto klass quit replied?
				state function fun reply pass err
				private public params log dbg exit?
				entity behavior store listen agent
				get put post delete).each do |cmd|
			@sandbox.delegate cmd.to_sym, self
		end
	end

	# add script-accessible (unsafe) variables
	def add_script_variables
		%w(outbox classes functions required local_set
		   states state).each do |var|
			eval "@sandbox.instance_variable_set :@#{var}, @#{var}"
		end
	end

	# the given block will have no access to the environment
	# except what is explicitly given above
	def sandbox(args={}, &block)
		args.each {|arg,val| @sandbox.instance_variable_set "@#{arg}", val}
		return_value = untraced(1) { @sandbox.sandbox &block }
		args.each {|arg,val| @sandbox.instance_variable_set "@#{arg}", nil}
		return_value
	end

	# load a script file
	def load_script(name)
		File.read name
	end

	public

	# add a script to the environment.
	# this method can't really get shorter or simpler, unfortunately.
	# TODO: set SAFE=4 and see what happens.
	def add_script(name, text=nil)
		untraced(2) do
			# push previous require (depth-first order)
			protect :required do
				text ||= load_script name
				@required = [].taint
				# repeat until script and dependencies are loaded
				while true
					sandbox(:script => name, :text => text, :env => self) do
						error = [].taint
						Thread.new(@script, @text, error, self) \
						do |script,text,error,box|
							$env = box.chooser
							$SAFE = 0
							begin
								box.untraced(0,3) do
									begin
										box.instance_eval text, script
									rescue
										box.rename_backtrace $!, '(toplevel)'
										fail $!
									end
								end
							rescue
								error << $!
							end
						end.join
						# bubble real errors
						unless (error = error[0]).nil?
							unless error.message == "require"
								$stderr.puts format_err($!) if @superfatal
								fail error
							end
						end
					end
					# load required files
					break if @required.empty?
					until @required.empty?
						to_include = @required.shift
						add_script to_include
						@included << to_include
					end
				end
			end
		end
	end

	private

	# make a stack of instance variables for nested calls
	def protect(*args, &block)
		backup = {}
		params = args.map {|arg| backup[arg] = eval "@#{arg}"}
		params.clear unless block.arity > 0
		return_value = untraced(2) { block.call *params }
		backup.each {|arg,val| eval "@#{arg} = val"}
		return_value
	end

	# ensure that the caller function was called
	# from a sandbox. FIXME must be a better way to do this
	def must_call_from_sandbox!
		return unless @sandbox_check
		unless /sandbox\.rb/ =~ caller[1]
			raise "illegal env -> env call"
		end
	end

	# synchronize on a mutex for the given name
	def sync(name, &block)
		mutex = nil
		@mutex.synchronize do
			mutex = eval "@#{name}_mutex ||= Mutex.new"
		end
		untraced(2) { mutex.synchronize &block }
	end

	public

	# run the script environment. any errors will be thrown
	# from self.join. won't actually execute scripts until
	# the start message is recieved or start! is called.
	def run
		return if @trying_to_run
		@trying_to_run = true
		Thread.pass until @start
		@outbox << [:started, nil, nil]
		Thread.pass
		@main_thread = Thread.new(self) do |env|
			env.send :script_main
		end
	end

	# give the environment the green light
	def start!
		@start = true
	end

	# run right now, don't wait for start signal
	def run!
		start!
		run
	end

	private

	# main script loop
	def script_main
		begin untraced(2,4) do
			sandbox do
				$env = chooser
				until $env.exit?
					$env.start
					Thread.pass
				end
			end; end
		rescue Exception => e
			err format_error(e)
		end
		done!
		nil
	end

	# require that an operation be in global scope
	def global_required
		return if current_state == :global
		raise "operation not allowed dynamically"
	end

	# require that an operation NOT be in global scope
	def global_forbidden
		return if current_state != :global
		raise "operation not allowed globally"
	end

	public

	# join the environment's main thread. calls to join may block
	# and may throw exceptions from scripts.
	def join(timeout=nil)
		@main_thread.join(@timeout||timeout) if @main_thread
		@pipe_thread.join(@timeout||timeout) if @pipe_thread
		@io_thread.join(@timeout||timeout) if @io_thread
		# fail(@error[0]) if @error and @error[0]
		exit unless @in_memory
		nil
	end

	# signal main thread completion
	def done!
		@done = true
		@main_thread = nil
	end

	# first, tell the script to exit, then tell IO to stop
	# (which it won't until the script does)
	def shutdown!(message_id=nil)
		return if @shutdown
		@pipe.write Message.system(:quit, :message_id => message_id)
		@quit_sent = true
		@exit = true
		@shutdown = true
	end

	# threads exit when shutdown signalled and scripts exit
	def shutdown?
		@shutdown && @done
	end

	private

	# pipe reader loop
	def pipe_main
		until shutdown?
			Thread.pass until @pipe
			message = @pipe.read
			if message
				sync :inbox do
					@inbox << message
				end
				break if message.command == :quit
			end
			Thread.pass
		end
		@pipe_closed = true
	end

	# io processing loop
	def io_main
		until shutdown? && @pipe_closed && @quit_sent
			handle_messages
			send_messages
			Thread.pass
		end
		@pipe.close
		@io_done = true
	end

	# handle messages in inbox
	def handle_messages
		until @inbox.empty?
			message = sync :inbox do
				@inbox.shift
			end
			next unless message
			handle message
		end
	end

	# send messages from outbox
	def send_messages
		until @outbox.empty?
			message = sync :outbox do
				@outbox.shift
			end
			send_message message
		end
	end

	# handle a message
	def handle(message)
		begin
			case message.command
			when :start then run!
			when :quit
				shutdown!(message[:message_id])
				@timeout = message[:timeout] # FIXME: ???
			when :load then
				add_script message[:file], message[:text]
				@outbox << [:loaded, nil, nil, message.params]
			when :ping then
				@outbox << [:pong, nil, nil, message.params]
			when :mapped then nil
			when :reply then handle_reply message
			# TODO: get source host in action message
			when :action
				# FIXME: we need to decide when path is a string vs. URI
				dbg "received action request: #{message.url}"
				path = message.url
				path = path.path if path.kind_of? URI
				action path, message.params
			else
				params = message.params.merge({:command => message.command})
				@outbox << [:no_command, nil, nil, params]
			end
		rescue Exception => e
			err format_error(e), message[:message_id]
		end
	end

	# handle a GET or POST message reply
	def handle_reply(message)
		sync :replies do
			@replies << message
		end
	end

	# delete a reply from the incoming array
	def delete_reply(message)
		@replies.delete message
	end

	# taint the params hash and call the given handler on the sandbox
	def call_handler(object, params, path, &block)
		self[:request_uri] = path
		params.taint
		sandbox :obj => object, &block
	end

	# call an action on the environment TODO break this function up
	def action(path, params)
		Thread.new(self, path, params) do |env,path,params|
			$env = env.instance_variable_get(:@sandbox).chooser
			begin
				env.local_set.call :params => params.stringify!
				dbg "trying to find handler for #{path}"
				# first look for a handler
				block, obj = resolve_handler path
				dbg "resolved (listen) handler for #{path}" if block
				# otherwise look for an action
				unless block
					map_id, action = env.send :resolve_path, path, params
					block = env.send :resolve_action, map_id, action, params
					dbg "resolved (function) handler for #{path}"
					obj = @sandbox
				end
			rescue Exception => e
				$stderr.puts format_error(e) if @superfatal
				$env.reply :error => format_error(e)
			end
			if block
				dbg "calling handler"
				# TODO: set source host as a param
				begin
					env.send :call_handler, obj, params, path do
						@obj.instance_exec &block
					end
					$env.reply unless $env.replied?
				rescue Exception => e
					$stderr.puts format_error(e) if @superfatal
					$env.reply :error => format_error(e) unless $env.replied?
				end
			else
				@outbox << [:not_found, nil, nil, params.merge({:path => path})]
			end
		end
	end

	# look up a handler for this path
	def resolve_handler(path)
		parts = path.split('/').reject {|s| s.empty?}
		@handlers.each do |regex,block|
			return block if regex.match_all? parts[0]
		end
		nil
	end

	# resolve path into map context and action name
	def resolve_path(path, params)
		parts = path.split('/').reject {|s| s.empty?}
		map_id = parts.shift
		while parts.size > 1
			map_id = resolve_part map_id, parts.shift, path, params
			return nil, nil unless map_id
		end
		part = parts.shift || ''
		return map_id, part
	end

	# resolve part of a path
	def resolve_part(map_id, part, path, params)
		if @url_patterns[map_id].nil?
			return(host_error(:no_path, path, params))
		end
		ids = @url_patterns[map_id].keys.select do |pattern|
			pattern.match_all? part
		end
		if ids.empty?
			return(host_error :no_path, path, params)
		elsif ids.size > 1
			return(host_error :ambiguous_path, path, params)
		else
			return(@url_patterns[map_id][ids[0]])
		end
	end

	# resolve action name in map context into block
	def resolve_action(map_id, action, params)
		return nil unless map_id && action
		begin
			action = action.to_sym unless action == ""
			block, visibility = @listeners[map_id][action]
		end
		# TODO: check visibility
		return block
	end

	# send error message to host controller
	def host_error(error, path, params)
		@outbox << [error, nil, nil, params.merge({:path => path})]
		nil
	end

	# format an action error into something to send as a reply
	def format_error(error)
		"#{error}\n" + (error.backtrace.map{|l| "\t#{l}"}).join("\n")
	end
	alias :format_err :format_error

	# send outgoing message to host FIXME
	def send_message(message)
		command, host, url, params, result, done = message

		msg = if not (host or url)
			Message.system(command, params)
		else
			Message.new(command, host, url, params)
		end

		@pipe.write msg

		begin
			# FIXME: sync/async should be an arg of the message maybe?
			if [:get, :post, :put, :delete, :load_agent].include? command
				wait_for_reply_to msg, result, done
			end
		rescue Exception => e
			err format_error(e)
		end
	end

	# wait for a reply in a new thread FIXME break inner code into new method
	def wait_for_reply_to(message, result, status)
		Thread.new(self) do |env|
			begin
				found = false
				while !found
					sync :replies do
						@replies.each do |reply|
							next unless reply.replies_to? message
							env.send :delete_reply, reply
							result << reply
							status << reply[:error] || :ok
							found = true
							break
						end
					end
					Thread.pass
				end
			rescue Exception => e
				err format_error(e)
			end
		end
	end

	# map a sub-url pattern
	def map_pattern(pattern, &block)
		protect :map_id do |old_map_id|
			@map_id += "\\/" + pattern.source
			@url_patterns[old_map_id] ||= {}.taint
			@url_patterns[old_map_id][pattern] = @map_id
			sandbox &block
		end
	end

	# map a root url
	def map_root(prefix, &block)
		global_required
		protect :map_id, :protection_level do
			@map_id = prefix.to_s
			@protection_level = :public
			@outbox << [:map, nil, nil, {:regex => /#{prefix}/}]
			sandbox &block
		end
	end

	# handle a GET, PUT, POST, or DELETE request.
  def handle_request (verb, url, body, params)
    uri = URI.parse url
    host = "#{uri.host}:#{uri.port}".to_host
    result, status = [], []
		newp = params.merge({:body => body.to_s})
    $env << [verb, host, uri.path, newp, result, status]
    Thread.pass while result.empty?
    reply = result[0]
    [reply[:code], reply[:body]]
  end

	# try to call a script-defined function
	def method_missing(id, *args, &block)
		must_call_from_sandbox! # hehehe
		untraced(5) do
			name = id.id2name.to_sym
			[current_state, :global].each do |state|
				next unless @functions[state].include? name
				return sandbox do
					begin
						@functions[state][name].call *args, &block
					rescue Exception => e
						self.rename_backtrace e, name
						fail e
					end
				end
			end
		end
		super id, *args
	end

	######################
	## SCRIPT FUNCTIONS ##
	######################

	public

	# add something to the outbox
	def <<(msg)
		must_call_from_sandbox!
		sync :outbox do
			@outbox << msg
		end
	end

	# the current state
	def current_state
		@state[0]
	end

	# require another file (depth-first order)
	def req(script)
		must_call_from_sandbox!
		unless @included.include? script
			@required << script
			raise "require"
		end
	end

	# map a host url pattern
	def map(arg, &block)
		must_call_from_sandbox!
		@map_id ? map_pattern(arg, &block) : map_root(arg, &block)
	end

	# jump to another state
	def goto(state)
		raise "invalid state" unless @states.include? state
		@state[0] = state
	end

	# exit the state machine
	def quit
		must_call_from_sandbox!
		@exit = true
	end

	# declare a function in this state
	# if it's inside a map block, it will be used
	# as a message handler
	def function(name, &block)
		must_call_from_sandbox!
		if @map_id
			log "mapping listener #{@map_id}/#{name}"
			@listeners[@map_id] ||= {}.taint
			@listeners[@map_id][name] = [block, @protection_level]
		else
			@functions[current_state][name.to_sym] = block
			@sandbox.delegate name, self
		end
	end
	alias :fun :function

	# declare a url map that is also a function,
	# which is the same as a map block containing
	# a function which handles all requests
	def listen(regex, object=@sandbox, &block)
		must_call_from_sandbox!
		raise "listeners cannot appear inside maps" if @map_id
		@handlers[regex] = [block, object]
		@outbox << [:map, nil, nil, {:regex => regex}]
	end

	# declare a new state (nested states not allowed)
	def state(name, &block)
		# must_call_from_sandbox!
		global_required
		@states << name unless @states.include? name
		@functions[name] ||= {}.taint
		@classes[name] ||= {}.taint
		goto name
		sandbox &block
		goto :global
	end

	# protection level for message handlers;
	# private handlers can only be accessed from
	# hosts in an ACL, by default just the handling
	# host
	def private
		must_call_from_sandbox!
		@protection_level = :private
	end

	def public
		must_call_from_sandbox!
		@protection_level = :public
	end

	# get action parameters
	def params
		must_call_from_sandbox!
		@local_get.call 'params'
	end

	# get whether there has been a reply
	def replied?
		must_call_from_sandbox!
		@local_get.call 'replied'
	end

	# thread pass
	def pass
		must_call_from_sandbox!
		Thread.pass
	end

	# create an agent
	def agent(name, &block)
		@agents[name] = Agent.new(name,&block)
	end
  
	# issue a GET request
  def get(url, body, params)
		must_call_from_sandbox!
    handle_request :get, url, body, params
  end
  
	# issue a PUT request
  def put(url, body, params)
		must_call_from_sandbox!
    handle_request :put, url, body, params
  end
  
	# issue a POST request
  def post(url, body, params)
		must_call_from_sandbox!
    handle_request :post, url, body, params
  end
  
	# issue a DELETE request
  def delete(url, body, params)
		must_call_from_sandbox!
    handle_request :delete, url, body, params
  end

	# is the script env done?
	def exit?
		@exit
	end

	# reply to a GET or POST
	def reply(params = {})
		must_call_from_sandbox!
		raise "already replied!" if $env.replied?
		@local_set.call 'replied' => true
		params[:code] ||= 200 unless $env.params[:error]
		params[:message_id] = $env.params[:message_id]
		@outbox << [:reply, nil, nil, params]
	end

	# send a debug message
	def dbg(msg)
		log msg, :level => :debug
	end

	# send a log message
	def log(msg, options={})
		@outbox << [:log, nil, nil, options.merge({:message => msg})]
	end

	# send an error message
	def err(msg, message_id=nil)
		$stderr.puts "FATAL XXX: #{msg}" if @superfatal
		@outbox << [:error, nil, nil, 
			{	:message => msg, :level => :error,
				:message_id => message_id}]
	end

end
