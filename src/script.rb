require 'sandbox'
require 'rubygems'
require 'ruby2ruby'

require 'mv'

# A state machine in a f.f.sandbox.
class Script

	# top-level define-time methods for scripts
	module Definers
		# declare a state
		def state(name, &block)
			raise 'nested states' if @state
			@states[name.to_sym] = {}
			@state = name.to_sym
			yield
			@state = nil
		end
		# unknown names are handlers
		def method_missing(id, *args, &block)
			return super if args.any? or @state.nil?
			@states[@state][id.id2name.to_sym] = block
		end
	end

	# top-level run-time methods for scripts
	module Runners
		# run the state machine; return last evaluated
		# expression after a goto
		def __main(prev_thread_id)
			MV.__continue(prev_thread_id)
			@state = :default
			@stopping = false
			@running = true
			no_result = :no_result
			result = no_result
			until @stopping
				event = :start
				block = @states[@state][event]
				raise 'no block' unless block
				result = no_result
				catch(:goto) do
					result = block.call
				end
				break if result != no_result
			end
			@finished = true
			@running = false
			@stopping = false
			result
		end
		# handle an http request
		def __handle(id, body, params, headers)
			MV.action(id, body, params, headers)
		end
		# jump to a new state
		def goto(new_state)
			raise 'bad state' unless @states[new_state]
			@state = new_state
			throw :goto
		end
		# re-defines the define-time method-missing
		def method_missing(id, *args)
			raise "no such method #{id.id2name}"
		end
		# trigger a script handler
		def trigger(action)
			if (block = @states[state][action])
				block.call
			else
				raise "no action #{action} in state #{state}"
			end
		end
		# returns the current state; also hides the define-time version
		def state
			@state
		end
	end

	attr_reader :name, :routes
	
	# create a new script
	def initialize(name, options={})
		@name = name
		@sandbox = Sandbox.safe
		@regex = /\(eval\):([0-9]+)/
		@files, @size = [], 0
		@fix_errors = false
		@options = options.merge(:safelevel => 3, :timeout => 5)
		@routes = {}
		import 'Script::Definers'
		eval '@states = {}; @state = nil'
	end

	# get the 'current line' of the sandbox
	def current_line
		begin
			@sandbox.eval "raise 'foo'"
		rescue Sandbox::Exception => e
		end
		lines = e.backtrace.select {|l| @regex =~ l}
		@regex.match(lines[0])[1].to_i
	end

	# evaluate a file. it will be added to the
	# improved error reporting.
	def eval_file(name, text=nil)
		base = current_line
		text ||= File.read(name)
		size = text.split("\n").size
		@sandbox.eval(text+";nil")
		@files << [name,@size+base,size]
		@size += size
	end

	# evaluate script text
	def eval(str, options={})
		raise "can't load while running" if @running
		begin
			@sandbox.eval str, @options.merge(options)
		rescue Sandbox::Exception => e
			fail(@fix_errors ? fix_error(e) : e)
		end
	end

	# fix a sandbox error
	def fix_error(e)
		error_sub(e.message)
		e.backtrace.each {|err| error_sub(err) }
		
		line1 = nil
		e.message.sub!(/.*/) do |str|
			m = /([^:]+): ([^:]+:[0-9]+:[^:]+): (.+)/.match str
			line1 = m[2]
			"#{m[1]}: #{m[3]}"
		end

		e.backtrace.unshift line1
		# e.backtrace.reject! {|err| /in `_eval'/ =~ err}
		e.backtrace.reject! {|err| /sandbox\.rb/ =~ err}

		e
	end

	# make source line substitutions on an error line
	def error_sub(err)
		err.sub!(@regex) do |str|
			line = @regex.match(str)[1].to_i
			file, line = error_source line
			"#{file}:#{line}"
		end
	end

	# find the actual source of an error
	def error_source(line)
		puts "determining source of #{line}"
		if @files.any? and line < @files[0][1]
			return ["(eval)", line-@base+1]
		end
		@files.each do |file|
			name, base, size = file
			if line >= base and line < base+size
				return [name, line-base+1]
			end
		end
		max = @files.any? ? (@files[-1][1]+@files[-1][2]) : @base
		["(eval)", line-max+1]
	end

	# explicitly declare a state
	def state(name, &block)
		eval "state :#{name}, &(#{block.to_ruby})"
	end

	# import a module into the script
	def import(name_or_module)
		if name_or_module.is_a? Module
			@sandbox.import name_or_module
		else
			@sandbox.import Kernel.eval(name_or_module)
			@sandbox.eval "class << self; include #{name_or_module}; end; nil"
		end
	end

	# reset state definitions
	def reset
		eval "@states = {}; @state = nil"
	end

	# get the next command
	def command
		@sandbox.eval "MV.read_out"
	end

	%w(quit pause abort).each do |action|
		define_method action do
			@sandbox.eval "__#{action}"
		end
	end

	# handle an http request
	def handle(id, body, params, headers)
		args = [id, body, params, headers]
		$thread[:script] = self
		@sandbox.eval "__handle(*#{args.inspect})"
	end

	# run the state machine
	def run
		raise 'already running' if running?
		unless @ran
			$thread[:script] = self
			import 'Script::Runners'
			@sandbox.ref MV
			@sandbox.ref MV::Request
			@sandbox.eval 'self.taint'
			@ran = true
		end
		@failed = false
		@finished = false
		@base = current_line
		puts "base = #{@base}" # DEBUG
		self.eval "__main(#{MV.thread_id})", :safelevel => 4
	end

	# stop the state machine
	def stop
		return unless running?
		return if stopping?
		@sandbox.eval '@stopping = true'
	end

	# the script failed and is no longer running.
	def failed!
		@sandbox.eval '@stopping = false'
		@sandbox.eval '@running = false'
		@failed = true
	end

	# did the script fail?
	def failed?
		@failed
	end

	# did the script run and then stop?
	def finished?
		@finished
	end

	# is the script running?
	def running?
		@sandbox.eval '@running'
	end

	# is the script stopping?
	def stopping?
		@sandbox.eval '@stopping'
	end

end
