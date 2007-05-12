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

require 'thread'
require 'sandbox'
require 'pipe'
require 'host'
require 'untrace'


# Script environment handles states, functions, classes,
# messaging, url mapping, sandboxing, and security.
class Environment

	include Untrace

	# set stuff up, taint some of it
	def initialize(input=$stdin, output=$stdout)
		@pipe = MessagePipe.new input, output
		@included = []
		@inbox = []
		@replies = []
		@sandbox = Sandbox.new
		@mutex = Mutex.new
		@state = [:global].taint
		@classes = {}.taint
		@functions = {}.taint
		@required = [].taint
		@states = [].taint
		@outbox = [].taint
		@url_patterns = {}.taint
		@listeners = {}.taint
		state(:global) {}
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
		%w(	map current_state resource req
				require k goto klass delegate
				state function fun reply pass
				private public params outbox).each do |cmd|
			@sandbox.delegate cmd.to_sym, self
			@sandbox.delegate nil, self
		end
	end

	# add script-accessible (unsafe) variables
	def add_script_variables
		%w(outbox classes functions required
		   states state io_thread).each do |var|
			eval "@sandbox[:#{var}] = @#{var}"
		end
	end

	# the given block will have no access to the environment
	def sandbox(args={}, &block)
		@sandbox ||= Sandbox.new
		args.each {|arg,val| @sandbox[arg] = val}
		return_value = untraced(1) { @sandbox.sandbox &block }
		args.each {|arg,val| @sandbox[arg] = nil}
		return_value
	end

	# load a script file
	def load_script(name)
		File.read name
	end

	# add a script to the environment
	def add_script(name, text=nil)
		untraced(2) do
			# push previous require (depth-first order)
			protect :required do
				text ||= load_script name
				@required = [].taint
				# repeat until script and dependencies are loaded
				while true
					sandbox(:script => name, :text => text) do
						error = [].taint
						Thread.new(@script, @text, error, self) do |script,text,error,box|
							$SAFE = 0
							begin
								box.untraced(0,3) do
									begin
										box.instance_eval text, script
									rescue Exception => e
										box.rename_backtrace e, '(toplevel)'
										fail e
									end
								end
							rescue
								error << $!
							end
						end.join
						# bubble real errors
						unless (error = error[0]).nil?
							raise error unless error.message == "require"
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

	# make a stack of instance variables for nested calls
	def protect(*args, &block)
		backup = {}
		args.each {|arg| backup[arg] = eval "@#{arg}"}
		return_value = untraced(2) { block.call }
		backup.each {|arg,val| eval "@#{arg} = val"}
		return_value
	end

	# synchronize on a mutex for the given name
	def sync(name, &block)
		mutex = nil
		@mutex.synchronize do
			mutex = eval "@#{name}_mutex ||= Mutex.new"
		end
		untraced(2) { mutex.synchronize &block }
	end

	# run the script environment. any errors will be thrown
	# from self.join.
	def run
		@main_thread = Thread.new(self) do |env|
			env.script_main
		end
	end

	# main script loop
	def script_main
		@error = []
		@sandbox[:main_thread] = Thread.current
		$env = self
		begin untraced(2,4) do
			sandbox do
				until @exit
					start
					Thread.pass
				end
			end; end
		rescue
			@error << $!
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

	# join the environment's main thread. calls to join block
	# and may throw exceptions from scripts.
	def join(timeout=nil)
		@main_thread.join(timeout) if @main_thread
		@pipe_thread.join(timeout) if @pipe_thread
		@io_thread.join(timeout) if @io_thread
		fail(@error[0]) if @error[0]
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
		@shutdown && @done
	end

	# pipe reader
	def pipe_main
		until shutdown?
			message = @pipe.read
			if message
				sync :inbox do
					@inbox << message
				end
			end
			Thread.pass
		end
		Thread.exit
		@pipe_closed = true
	end

	# io processing loop
	def io_main
		until shutdown? && @pipe_closed
			handle_messages
			send_messages
			Thread.pass
		end
		@pipe.close
		Thread.exit
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
		case message.command
		when :quit then shutdown!
		when :reply then handle_reply message
		when :action then action message.url, message.params
		else @outbox << [	:no_command, message[:message_id],
											message.command.to_s]
		end
	end

	# handle a GET or POST message reply
	def handle_reply(message)
		@replies << message
	end

	# delete a reply from the incoming array
	def delete_reply(message)
		@replies.delete message
	end

	# call an action on the environment
	def action(path, params)
		Thread.new(self, path, params) do |env,path,params|
			map_id, action = env.resolve_path path, params
			block = env.resolve_action map_id, action, params
			if block
				$_params = params
				begin
					env.sandbox &block
				rescue Exception => e
					reply :error => format_error(e)
				end
			end
		end
	end

	# resolve path into map context and action name
	def resolve_path(path, params)
		parts = path.split '/'
		map_id = parts.shift
		while parts.size > 1
			map_id = resolve_part map_id, parts.shift, path, params
			return nil, nil unless map_id
		end
		return map_id, parts.shift
	end

	# resolve part of a path
	def resolve_part(map_id, part, path, params)
		if @url_patterns[map_id].nil?
			return(host_error :no_path, path, params)
		end
		ids = @url_patterns[map_id].keys.select do |pattern|
			pattern =~ part
		end
		if ids.empty?
			return(host_error :no_path, path, params)
		elsif ids.size > 1
			return(host_error :ambiguous_path, path, params)
		else
			return(ids.shift)
		end
	end

	# resolve action name in map context into block
	def resolve_action(map_id, action, params)
		return nil unless map_id && action
		block = env.listeners[map_id][action]
		host_error(:no_action, path, params) if block.nil?
		return block
	end

	# send error message to host controller
	def host_error(error, path, params)
		@outbox << [error, nil, path, params]
		nil
	end

	# format an action error into something to send as a reply
	def format_error(error)
		"#{error}\n" + (error.backtrace.map{|l| "\t#{l}"}).join('\n')
	end

	# send outgoing message to host
	def send_message(message)
		command, host, url, params, result, done = message
		@pipe.write Message.new(command, host, url, params)
		if [:get, :post].include? command
			wait_for_reply_to message, result, done
		end
		nil
	end

	# wait for a reply in a new thread
	def wait_for_reply_to(message, result, status)
		Thread.new(self) do |env|
			@replies.each do |reply|
				next unless reply.replies_to? message
				env.sync(:replies) { env.delete_reply reply }
				status << reply[:error] || :ok
				result << reply
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
			@map_id = prefix
			@protection_level = :public
			@outbox << [:map, nil, prefix, {}]
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

	alias :req :require

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
			@listeners[@map_id] ||= {}.taint
			@listeners[@map_id][name] = [block, @protection_level]
		else
			@functions[current_state][name] = block
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

	# add something safely to outbox array
	def <<(message)
		sync :outbox do
			@outbox << message
		end
	end

	# thread pass
	def pass
		Thread.pass
	end

	# reply to a GET or POST
	def reply(params = {})
		params[:message_id] = $_params[:message_id]
		@outbox << [:reply, nil, nil, params]
	end

	# try to call a script-defined function
	def method_missing(id, *args, &block)
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

end
