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

require 'includes'
require 'util/safe'
require 'util/uid'
require 'protocol/message'


module MV::Script

	class Environment < Module

		extend MV::Util::SafeErrors

		attr_reader :scripts, :host
		attr_accessor :stdout

		def initialize(host)
			unsafe
			@host = host
			@scripts = []
			@meta_proto = ''.taint
			@states = [].taint
			@required = [].taint
			@included = []
			@stdout = ''.taint
			@state = [:global].taint
			@classes = {}.taint
			@variables = {:global => {}.taint}.taint
			@functions = {:global => {}.taint}.taint
			@signals = [].taint
			@outbox = [].taint
			@listeners = [].taint
			@handlers = []
			@all_functions = [].taint
			@log = @host.logger :script
			@outbox_mutex = Mutex.new.taint
			@signals_mutex = Mutex.new.taint
			@uid = nil
		end

		def sync(resource, &block)
			eval("@#{resource}_mutex").synchronize &block
		end

		def responders
			unsafe
			@all_functions
		end

		def load_config
			unsafe
			return nil unless @uid
			return {} if host.config.ignore_config
			file = @host.file :environment, @uid
			if File.exists? file
				text = File.read(file)
				start_safe(true, proc {eval text})
			else
				{}
			end
		end

		def handles?(signal)
			unsafe
			name = "on_#{signal}".to_sym
			return true if @functions[current_state][name]
			return true if @functions[:global][name]
			false
		end

		def store_config(config)
			unsafe
			return unless @uid and config
			file = @host.file(:environment, @uid)
			File.open(file, 'w') {|f| f.write config.inspect}
		end

		def setup_env(start_state=nil)
			unsafe

			@protocol = @host.protocol
			@protocol.register_text @meta_proto, :message
			@stdout = ''.taint
			@exit = [false].taint
			@state = [start_state || @states[0]].taint
		end

		def protocol
			unsafe
			@meta_proto
		end

		def teardown_env
			unsafe
			store_config sanitize(@config) if teardown_config?
		end

		def start_env(start_state=nil)
			unsafe

			setup_env start_state
			@config = setup_config? ? load_config.taint : nil

			block = proc do
				run @config
			end
			start_safe false, block
		end

		def setup_config?
			@functions[:global][:setup] && \
			@functions[:global][:setup].arity > 0
		end

		def teardown_config?
			@functions[:global][:teardown] && \
			@functions[:global][:teardown].arity > 0
		end

		def sanitize(hash)
			unsafe
			hash.untaint
		end

		def start_safe(join, block, *args)
			unsafe
			
			errs = [].taint
			res = [].taint
			thread = Thread.new(self,block,errs,res,*args) \
					do |env,block,errs,res,*args|
				$block = block
				$args = args
				$env = env
				$SAFE = env.host.config.safe_level
				begin
					res << env.instance_eval do
						$block.call *$args
					end
				rescue
					errs << $!
					env.err $!
				end
			end
			if join
				thread.join
				raise errs[0] unless errs.empty?
				res[0]
			else
				@handlers << thread
			end
		end

		def join
			unsafe

			self.exit

			@handlers.each do |thread|
				next unless thread
				thread.join(host.config.shutdown_timeout)
				thread.kill
			end
			if @thread
				@thread.join(host.config.shutdown_timeout)
				@thread.kill
			end

			teardown_env
			flush
		end

		def compile(script)
			unsafe

			self.add_script @host.find_script(script)
			base = File.expand_path(File.dirname(__FILE__) + '/../..')
			filename = "#{base}/data/local/scripts/#{script}"
			filename << ".rb" unless filename[-3..-1] == ".rb"
			self.add_script Compiler.load(filename)
		end

		def add_script(a_script)
			unsafe

			# push required list
			req_bak = @required
			@required = [].taint

			# parse the script in a sandbox
			@properties = {}.taint
			start_safe(true, proc {eval a_script.text, binding, a_script.file})
			a_script.set_properties @properties
			@uid ||= @properties[:uid]
			
			# load required files
			need_reload = false
			until @required.empty?
				req = @required.shift
				next if @included.include? req
				@included << req
				need_reload = true
				compile req
			end

			# reload this script (because of requires)
			if need_reload
				@listeners.clear
				self.add_script a_script
			else
				@scripts << a_script
			end

			# add listeners to host
			until @listeners.empty?
				type, content, block = @listeners.shift
				block.untaint
				@host.listen type, content, block, self
			end

			# pop required list
			@required = req_bak
			self
		end

		def flush
			unsafe

			# flush output streams
			$stdout.write @stdout
			@stdout = ''.taint
			@log.flush

			# sort by priority
			sync(:outbox) do
				@outbox.sort!
			end

			# dispatch signals
			until @signals.empty?
				mode, res, signal, args = \
				sync(:signals) do
					@signals.shift
				end
				@host.schedule_signal mode, res, signal, args
			end

			# dispatch outgoing messages
			until @outbox.empty?
				priority, mode, target, msg, response = \
				sync(:outbox) do
					@outbox.shift
				end
				unless msg.is_a? MV::Protocol::Message
					begin
						msg = @host.msg_with @protocol, *msg 
					rescue
						@log.log_err $!
					end
				end
				Thread.new(mode, target, msg, response) do |mode,target,msg,response|
					begin
						u = MV::Util.random_uid()
						puts "env #{host.short}: #{u} (1): mode = #{mode}, msg = #{msg.key}"
						reply = @host.send_to mode, target, msg
						puts "env #{host.short}: #{u} (2): mode = #{mode}, msg = #{msg.key}, class = #{reply.class}"
						response[1] = reply
						response[0] = true
					rescue
						puts $!
						response[1] = nil
						response[0] = true
					end
				end
			end
		end

		def unsafe
			raise "insecure method call from safe zone" if $SAFE > 0
		end

		###
		###  SAFE REGION
		### 

		[:uid, :name, :url, :version, :author].each do |prop|
			eval <<-END
				def #{prop}; @properties[:#{prop}]; end
				def #{prop}=(v); @properties[:#{prop}] = v; end
			END
		end

		def run(config)
			$SAFE = host.config.safe_level

			begin
				setup config
			rescue NoMethodError => e
			end

			start until exited?
			
			begin
				teardown config
			rescue NoMethodError => e
			end

			nil
		end

		def random_uid
			MV::Util.random_uid
		end

		def wait_on(something, size=1)
			while something.size < size
				Thread.pass
			end
			true
		end

		def script
			self
		end

		def exit
			@exit[0] = true
		end

		def require(script)
			script << '.rb' unless script[-3..-1] == '.rb'
			@required << script
		end

		def exited?
			@exit[0]
		end

		def puts(str)
			if $SAFE > 0
				str = str.to_s
				@stdout << str
				@stdout << "\n" unless str[-1,1] == "\n"
			else
				$stdout.puts str
			end
			str
		end
		
		def current_state
			@state[0]
		end

		def goto(new_state)
			raise "invalid state for goto" unless @functions[new_state]
			@state[0] = new_state
		end

		def in_global?
			current_state == :global
		end

		def state(name, &block)
			raise "nested states not allowed" unless in_global?
			@states << name
			@variables[name] ||= {}
			@functions[name] ||= {}
			goto name
			instance_eval &block
			goto :global
		end

		def k(name)
			@classes[name]
		end

		def unsign(crypt, uid)
			@host.keyring.unsign! uid, crypt
		end

		def msg(key, content={})
			[key, content]
		end

		def log(msg, type=:info)
			@log.log msg, type
		end

		def dbg(msg)
			log msg, :dbg
		end

		def err(err)
			@log.log_err err
		end

		def logger
			@log
		end

		def caller(n=2)
			begin
				raise 'foo'
			rescue
				return $!.backtrace[n]
			end
		end

		def send_with_priority(priority, mode, target, key, content={})
			begin
				if key.is_a? MV::Protocol::Message
					msg = key
				elsif key.is_a? Array
					msg = key
				else
					msg = msg(key, content)
				end
				response = [false,nil,msg[0]]
				sync(:outbox) do
					@outbox << [priority, mode, target, msg, response]
				end
				puts "#{host.short} spooling send, mode = #{mode}, msg = #{msg[0]}"
				if mode == :sync
					until response[0] || (@host.net_thread && !@host.net_thread.alive?)
						some_uid = MV::Util.random_uid
						puts "... #{host.short}: #{msg[0]} (#{some_uid}) from #{self.caller(3)}"
						if @host.net_thread
							@host.net_thread.run
						else
							Thread.pass
						end
						puts "xxx #{host.short}: #{msg[0]} (#{some_uid})"
					end
					raise "network went down" unless response[0]
					puts "#{host.short} unspooled #{response[2]} for #{msg[0]}: class = #{response[1].class}"
					response[1]
				end
			rescue
				puts $!
				return nil
			end
		end

		def send?(*args); send_with_priority(2, *args); end
		def send_(*args); send_with_priority(1, *args); end
		def send!(*args); send_with_priority(0, *args); end

		def signal_with(mode, res, signal, *args)
			sync(:signals) do
				@signals << [mode, res, signal, args]
			end
		end

		def signal?(*args)
			signal_with :signal?, (res = []), *args
			wait_on res
			res[0]
		end
		def signal (*args); signal_with :signal, [], *args; end
		def signal!(*args); signal_with :signal!, [], *args; end
		def signal1(*args); signal_with :signal1, [], *args; end

		def listen(type, content={}, &block)
			@listeners << [type,content,block]
		end

		def function(name, &block)
			@functions[current_state][name.to_sym] = block
			@all_functions << name
		end
		alias :fun :function

		def variable(name, value=nil)
			@variables[current_state][name.to_sym] = value
		end
		alias :var :variable

		# create a script-space 'safe' class
		def klass(class_name, superclass=nil, &block)
			superclass = @classes[superclass] if superclass
			superclass ||= Object
			c = @classes[class_name.to_sym] = Class.new(superclass, &block)
			eval "c.send :define_method, :inspect do
				\"#<#{class_name}:0x#{"%x"%[object_id]}>\"
			end"
		end

		def new(name, *args)
			name = name.to_sym
			raise "no such class #{name}" unless @classes[name]
			@classes[name].new *args
		end

		def method_missing(id, *args)
			name = id.id2name.to_sym

			# try for state function call
			fun = @functions[current_state][name]
			return fun.call(*args) if fun

			# try for global function call
			fun = @functions[:global][name]
			return fun.call(*args) if fun

			# try for variable get
			if name.to_s[-1,1] != '=' and args.size == 0
				if @variables[current_state].keys.include? name
					return @variables[current_state][name]
				elsif @variables[:global].keys.include? name
					return @variables[:global][name]
				end

			# try for variable set
			elsif name.to_s[-1,1] == '=' and args.size == 1
				arg = name.to_s[0...-1].to_sym
				if @variables[current_state].keys.include? arg
					return @variables[current_state][arg] = args[0]
				elsif @variables[:global].keys.include? arg
					return @variables[:global][arg] = args[0]
				end
			end

			# pass it along unhandled
			super(id, *args)
		end

		safe :compile, :flush, :run

	end

end
