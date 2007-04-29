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


# A sandbox object allows code blocks to run in a
# clean environment; if the blocks have $SAFE = 4,
# they are effectively cut off from the rest of
# the system.
class Sandbox
	def initialize; end
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


# YAML Object: reads/writes YAML into DOM
class YamlObject
	def initialize(hash)
		# TODO
	end
	def to_yaml
		# TODO
	end
	def self.from_yaml(yaml)
		# TODO
	end
	def method_missing(id, *args)
		name = id.id2name
		if name[-1,1] == '=' && @map.include?(name[0...-1])
			@map[name[0...-1]] = args[0]
		elsif @map.include?(name)
			@map[name]
		else
			super(id, *args)
		end
	end
end


# YAML Pipe: (de-)YAML-ize objects coming through the pipe.
# Objects to be YAML-ized should have a to_yaml method.
# Objects to be de-YAML-ized should have a static from_yaml
# method.
class YamlPipe
	def initialize(input=$stdin, output=$stdout)
		@in, @out = input, output
	end
	def read
		len = @in.readline.to_i
		text = @in.read len
		YamlObject.from_yaml text
	end
	def write(object)
		text = object.to_yaml
		@out.puts text.size
		@out.write text
	end
	def flush
		@out.flush
	end
end


# Script environment handles states, functions, classes,
# messaging, url mapping, sandboxing, and security.
class Environment

	# set stuff up, taint some of it
	def initialize(input=$stdin, output=$stdout)
		@pipe = YamlPipe.new input, output
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
		start_io_thread
		add_script_commands
		add_script_variables
	end

	# start IO processing thread
	def start_io_thread
		@pipe_thread = Thread.new(self) do |env|
			env.pipe_main
		end
		@io_thread = Thread.new(self) do |env|
			env.io_main
		end
	end

	# add script-accessible (unsafe) functions
	def add_script_commands
		%w(	map listen ask? tell current_state
				require k method_missing goto
				state function fun klass).each do |cmd|
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
			rescue
				@error = $!
			end
		end
		nil
	end

	# join the environment's main thread. calls to join block
	# and may throw exceptions from scripts.
	def join
		@main_thread.join
		@io_thread.join
		raise @error if @error
		nil
	end

	# first, tell the script to exit, then tell IO to stop
	# (which it won't until the script does)
	def shutdown
		@sandbox[:exit] = true
		@shutdown = true
	end

	# pipe reader
	def pipe_main
		until @shutdown && @sandbox[:exit]
			message = @pipe.read
			sync :inbox do
				@inbox << message
			end
		end
	end

	# io processing loop
	def io_main
		until @shutdown && @sandbox[:exit]
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
			return unless message
			# TODO
		end
	end

	# send messages from outbox
	def send_messages
		# TODO
	end

	# flush output pipe
	def flush
		@pipe.flush
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
	def map(pattern, &block)
		if @map_id
			old_map_id = @map_id
			@map_id += "\\/" + pattern.source
			(@url_patterns[map_id] ||= {}.taint)[pattern] = @map_id
			sandbox &block
			@map_id = old_map_id
		else
			if current_state != :global
				raise "root urls cannot be declared dynamically" 
			end
			@map_id = pattern
			@outbox << [:host, :map,
				{	:pattern => pattern.to_s,
					:map_id => @map_id}]
			sandbox &block
			@map_id = nil
		end
	end

	# declare a message handler
	def listen(key, content={}, &block)
		raise "must declare handlers inside mapped url" unless map_id
		(@listeners[map_id] ||= {}.taint)[key] = [content, block]
	end

	# send a synchronous message and wait for the response
	def ask?(host, key, content={})
		raise "illegal operation in global scope" if current_state != :global
		response = []
		@outbox << [:sync, host, key, content, response]
		@io_thread.run while response.empty?
		response[0]
	end

	# send an asynchronous message
	def tell(host, msg)
		raise "illegal operation in global scope" if current_state != :global
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
	def function(name, &block)
		@functions[current_state][name] = &block
	end

	# declare a new class in this state
	def klass(name, parent=nil, &block)
		parent = k(parent) if parent
		@classes[current_state][name] = Class.new parent, &block
	end

	# declare a new state (nested states not allowed)
	def state(name, &block)
		raise "nested states not allowed" unless current_state == :global
		@states << name unless @states.include? name
		@functions[name] ||= {}.taint
		@classes[name] ||= {}.taint
		goto name
		sandbox &block
		goto :global
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
