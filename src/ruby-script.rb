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


$: << File.expand_path(File.dirname(__FILE__) + '/..')

require 'message'


# A sandbox object allows code blocks to run in a
# clean environment; if the blocks have $SAFE = 4,
# they are effectively cut off from the rest of
# the system.
class Sandbox
	def sandbox(&block)
		instance_eval &block
	end
	def [](key)
		eval "@#{key}"
	end
	def []=(key, value)
		if value.respond_to? :call
			self.send :define_method, key do |*args|
				value.call *args
			end
		else
			eval "@#{key} = value"
		end
	end
end


# Objects to be sent over pipe should have marshal
# and unmarshal methods
class ObjectPipe
	def initialize(input=$stdin, output=$stdout, &unmarshal)
		@in, @out, @unmarshal = input, output, unmarshal
	end
	def read
		len = @in.readline.to_i
		text = @in.read len
		@unmarshal.call text
	end
	def write(object)
		text = object.marshal
		@out.puts text.size
		@out.write text
		@out.flush
	end
end


# Message pipe just passes static unmarshal method to constructor
class MessagePipe < ObjectPipe
	def initialize(input=$stdin, output=$stdout)
		super(input, output) do |text|
			Message.unmarshal text
		end
	end
end


# Script environment handles states, functions, classes,
# messaging, url mapping, sandboxing, and security.
class Environment

	# set stuff up, taint some of it
	def initialize
		@pipe = MessagePipe.new
		@included = []
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
		%w(	map listen get post current_state
				require k method_missing goto
				state function fun klass delegate
				private public).each do |cmd|
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
				@error = $!
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
		raise @error if @error
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
			# TODO
		end
	end

	# send messages from outbox
	def send_messages
		# TODO
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

	# send a synchronous message and wait for the response
	def get(host, key, content={})
		global_forbidden
		response = []
		@outbox << [:sync, host, key, content, response]
		@io_thread.run while response.empty?
		response[0]
	end

	# send an asynchronous message
	def post(host, key, content={})
		global_forbidden
		@outbox << [:async, host, key, content]
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
			(@listeners[map_id] ||= {}.taint)[key] = \
				[content, block, @protection_level]
		else
			@functions[current_state][name] = &block
		end
	end
	alias :fun :function

	# declare a message handler
	def listen(key, content={}, &block)
		raise "must declare handlers inside mapped url" unless map_id
	end

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
		delegations.each do |object_name,methods|
			methods.each do |method|
				fun method do
					eval "$env.#{object_name}.#{method} params"
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
