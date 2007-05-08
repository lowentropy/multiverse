#
# Multiverse - p2p online virtual community
# Copyright (C) 2007  Nathan C. Matthews <lowentropy@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#


$: << File.dirname(__FILE__)

require 'sandbox'
require 'pipe'
require 'host'


# Script environment handles states, functions, classes,
# messaging, url mapping, sandboxing, and security.
class Environment

	# set stuff up, taint some of it
	def initialize
		@pipe = MessagePipe.new
		@included = []
		@inbox = []
		@sandbox = Sandbox.new
		@state = [:global].taint
		@classes = {}.taint
		@functions = {}.taint
		@required = [].taint
		@states = [].taint
		@outbox = [].taint
		@url_patterns = {}.taint
		@listeners = {}.taint
		state :global {}
		start_io_threads
		add_script_commands
		add_script_variables
	end

	# start IO processing threads
	def start_io_threads
		@pipe_thread = Thread.new(self) do |env|
			env.pipe_main
		end
		@io_thread = Thread.new(self) do |env|
			env.io_main
		end
	end

	# add script-accessible (unsafe) functions
	def add_script_commands
		%w(	map current_state resource
				require k method_missing goto
				state function fun klass delegate
				private public params reply).each do |cmd|
			@sandbox[cmd] = proc {|*args| self.send cmd, *args}
		end
	end

	# add script-accessible (unsafe) variables
	def add_script_variables
		@sandbox[:outbox] = @outbox
		@sandbox[:classes] = @classes
		@sandbox[:functions] = @functions
		@sandbox[:required] = @required
		@sandbox[:states] = @state
		@sandbox[:state] = @state
		@sandbox[:io_thread] = @io_thread
	end

	# the given block will have no access to the environment
	def sandbox(args={}, &block)
		@sandbox ||= Sandbox.new
		args.each {|arg,val| @sandbox[arg] = val}
		return_value = @sandbox.sandbox &block
		args.each {|arg,val| @sandbox[arg] = nil}
		return_value
	end

	# add a script to the environment
	def add_script(script)
		# push previous require (depth-first order)
		protect :required do
			text = load_script script
			@required = [].taint
			# repeat until script and dependencies are loaded
			while true
				sandbox(:script => script, :text => text) do
					error = [].taint
					# parse text in safe sandbox
					Thread.new(@script,@text,error) do |script,text,error|
						$SAFE = 4
						begin
							eval text, nil, script
						rescue
							error << $!
						end
					end
					# bubble real errors
					unless (error = error[0]).nil?
						raise error unless error.message == "require"
					end
				end
				# load required files
				break if @required.empty?
				add_script @required.shift until @required.empty?
				@included << script
			end
		end
	end

	# make a stack of instance variables for nested calls
	def protect(*args, &block)
		backup = {}
		args.each {|arg| backup[arg] = eval "@#{arg}"}
		return_value = block.call
		backup.each {|arg,val| eval "@#{arg} = val"}
		return_value
	end

	# synchronize on a mutex for the given name
	def sync(name, &block)
		mutex = eval "@#{name}_mutex ||= Mutex.new"
		mutex.synchronize &block
	end

	# run the script environment. any errors will be thrown
	# from self.join.
	def run
		@error = []
		@main_thread = Thread.new(self,error) do |env,error|
			sandbox = env.instance_variable_get :@sandbox
			sandbox[:main_thread] = Thread.current
			$env = env
			begin
				sandbox.sandbox do
					start until @exit
				end
				env.done!
			rescue
				error << $!
			end
		end
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

	# join the environment's main thread. calls to join block
	# and may throw exceptions from scripts.
	def join
		@main_thread.join if @main_thread
		@io_thread.join if @io_thread
		@pipe_thread.join if @pipe_thread
		raise @error[0] if @error[0]
		nil
	end

	# signal main thread completion
	def done!
		@done = true
		@main_thread = nil
	end

	# first, tell the script to exit, then tell IO to stop
	# (which it won't until the script does)
	def shutdown!
		@sandbox[:exit] = true
		@shutdown = true
	end

	# threads exit when shutdown signalled and scripts exit
	def shutdown?
		@shutdown && @finished
	end

	# pipe reader
	def pipe_main
		until shutdown?
			message = @pipe.read
			sync :inbox do
				@inbox << message
			end
		end
	end

	# io processing loop
	def io_main
		until shutdown?
			handle_messages
			send_messages
			flush
		end
	end

	# handle messages in inbox
	def handle_messages
		until @inbox.empty?
			sync :inbox do
				message = @inbox.shift
			end
			next unless message
			handle message
		end
	end

	# send messages from outbox
	def send_messages
		until @outbox.empty?
			sync :outbox do
				message = @outbox.shift
			end
			send_message message
		end
	end

	# handle a message
	def handle(message)
		case message.command
		when :quit then shutdown!
		when :action then action message.url, message.params
		else @outbox << [	:no_command, message[:message_id],
											message.command.to_s, {}]
		end
	end

	# call an action on the environment
	def action(path, params)
		Thread.new(self) do |env|
			map_id, action = resolve_path path, params
			block = resolve_action map_id, action, params
			$_params = params
			env.sandbox &block
		end
	end

	# resolve path into map context and action name
	def resolve_path(path, params)
		parts = path.split '/'
		map_id = parts.shift
		while parts.size > 1
			map_id = resolve_part map_id, parts.shift, path, params
		end
		return map_id, parts.shift
	end

	# resolve part of a path
	def resolve_part(map_id, part, path, params)
		if @url_patterns[map_id].nil?
			return host_error :no_path, path, params
		end
		ids = @url_patterns[map_id].keys.select do |pattern|
			pattern =~ part
		end
		if ids.empty?
			return host_error :no_path, path, params
		elsif ids.size > 1
			return host_error :ambiguous_path, path, params
		else
			return ids.shift
		end
	end

	# resolve action name in map context into block
	def resolve_action(map_id, action, params)
		block = env.listeners[map_id][action]
		return host_error :no_action, path, params if block.nil?
		return block
	end

	# send error message to host controller
	def host_error(error, path, params)
		@outbox << [error, nil, path, params]
		nil
	end

	# send outgoing message to host
	def send_message(message)
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
			@map_id = prefix
			@protection_level = :public
			@outbox << [:host, msg(:map, :prefix => prefix)]
			sandbox &block
		end
	end

	######################
	## SCRIPT FUNCTIONS ##
	######################

	# the current state
	def current_state
		@state[0]
	end

	# require another file (depth-first order)
	def require(script)
		unless @included.include? script
			@required << script
			raise "require"
		end
	end

	# map a host url pattern
	def map(arg, &block)
		@map_id ? map_pattern(arg, &block) : map_root(arg, &block)
	end

	# look up a class
	def k(name)
		@classes[current_state][name] || @classes[:global][name]
	end

	# jump to another state
	def goto(state)
		raise "invalid state" unless @states.include? state
		@state[0] = state
	end

	# declare a function in this state
	# if it's inside a map block, it will be used
	# as a message handler
	def function(name, &block)
		if @map_id
			@listeners[map_id] ||= {}.taint
			@listeners[map_id][name] = [block, @protection_level]
		else
			@functions[current_state][name] = &block
		end
	end
	alias :fun :function

	# declare a new class in this state
	def klass(name, parent=nil, &block)
		parent = k(parent) if parent
		@classes[current_state][name] = Class.new parent, &block
	end

	# declare a new state (nested states not allowed)
	def state(name, &block)
		global_required
		@states << name unless @states.include? name
		@functions[name] ||= {}.taint
		@classes[name] ||= {}.taint
		goto name
		sandbox &block
		goto :global
	end

	# delegate handler methods to an object
	def delegate(delegations = {})
		delegations.each do |object,methods|
			methods.each do |method|
				action, fun = method.is_a?(Hash) ?
					[method.keys[0], method.values[0]] :
					[method, method]
				fun action do
					eval "$env.#{object}.#{fun}"
				end
			end
		end
	end

	# protection level for message handlers;
	# private handlers can only be accessed from
	# hosts in an ACL, by default just the handling
	# host
	def private
		@protection_level = :private
	end

	def public
		@protection_level = :public
	end

	# get action parameters
	def params
		$_params
	end

	# reply to a GET or POST
	def reply(params = {})
		params[:message_id] = $_params[:message_id]
		@outbox << [:reply, nil, nil, params]
	end

	# try to call a script-defined function
	def method_missing(id, *args)
		name = id.id2name.to_sym
		[current_state, :global].each do |state|
			next unless @functions[state].include? name
			return sandbox { @functions[state].call *args }
		end
		super id, *args
	end

end
