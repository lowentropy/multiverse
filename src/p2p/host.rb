#! /usr/bin/ruby

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
require 'protocol/protocol'
require 'protocol/message'
require 'crypto/keyring'
require 'net/server'
require 'script/environment'
require 'script/script'
require 'script/compiler'
require 'util/logger'
require 'p2p/config'
require 'p2p/directory'
require 'p2p/info'
include MV::Protocol
include MV::Crypto
include MV::Net
include MV::Script


module MV::P2P

	# The host is the core of the p2p network. Its function is to
	# route different kinds of messages and signals: some to set
	# up the physical multiverse, some to do load balancing, trust
	# network management, etc.
	# It is also the network router for the viewer, server, and
	# client code. Lastly, it handles encryption/decryption and
	# users' keyrings.
	class Host
		
		attr_reader :protocol, :info, :config, :net, :keyring, :directory

		# load disk configurations
		def initialize(config=nil, net=nil)
			@loggers = {}
			@config = config || HostConfig.new
			@keyring = Keyring.new self
			@info = HostInfo.local self
			@protocol = Protocol.new(@config.debug)
			@directory = Directory.new self
			@net = net ? net.new(self) : Server.new(self)
			@net.owned_by self
			@directory[uid] = @info
			@protocol.register_protocol
			@environments = []
			@last_message_id = 0
			@logger = logger :host
			@signals = []
			@handlers = {}
			@config.scripts.each {|script| self.load script}
		end

		# use debug mode?
		def debug?
			config.debug
		end

		# short description (address)
		def short
			info.short
		end

	private

		# host log
		def log(*args)
			@logger.log *args
		end

	public

		# public key text of host
		def pubkey
			@keyring.pubkey
		end

		# host signature
		def sign(data)
			@keyring.sign data
		end

		# thread used by network server
		def net_thread
			@net.thread
		end

		# host address in [addr, port] format
		def address
			[@config.address, @config.port]
		end

		# start the network server
		def start
			log "starting host (#{config.short})..."
			@stop = false
			@thread = Thread.new(self) do |host|
				host.main
			end
			@net.start
			log "host started ok"
		end

		# returns this host's UID
		def uid
			@config.uid
		end

		# return a new logger
		def logger(name)
			@loggers[name] ||= MV::Util::Logger.new(self, name)
		end

		# main loop: flush environments and route signals
		def main
			@running = true
			until @stop
				@environments.each do |env|
					env.flush
				end
				until @signals.empty?
					mode, res, sig, args = @signals.shift
					Thread.new(self,res) do |host,res|
						res << host.send(mode, sig, *args)
					end
				end
				Thread.pass
			end
			log "exiting main loop", :dbg
			@running = false
		end

		# load a script environment
		def load(script)
			script = find_script(script) unless script.is_a? Script
			log "loading script '#{script.file}'"
			env = Environment.new self
			env.add_script script
			add_environment env
			env.start_env
		end

		# add a new environment
		def add_environment(env)
			@environments << env
			@handlers.values.each do |arr|
				arr[1] << env
			end
		end

		# find a local script by name
		def find_script(name)
			Compiler.load file(:script, name, 'rb')
		end

		# get an app directory name
		def dir(type)
			dir = config.send("#{type}_dir")
			dir = "/#{dir}" unless dir[0,1] == '/'
			config.app_root + dir
		end

		# get a file in the right place
		def file(type, name, ext=nil)
			name << ".#{ext}" if ext and name[-ext.size-1..-1] != ".#{ext}"
			"#{dir(type)}/#{name}"
		end

		# don't use :local for local-host messages
		def no_local_sends!
			@info.not_local!
		end

		# join with the host thread
		def join
			@thread.join
		end

		# shut down the host
		def shutdown
			# stop network
			log "signaling net shutdown..."
			@stop = true
			@net.shutdown
			# shut down all scripts
			log "stopping scripts..."
			@environments.each do |env|
				env.join
			end
			# join with main thread and network thread
			@thread.join if @thread
			log "waiting for net to close..."
			@net.join
			# stop and close all loggers
			log "shutdown complete. closing log files."
			@loggers.each do |name,log|
				log.close
			end
		end

		# listen for messages, returning sync replies
		def listen(key, content, block, env)
			@net.reserve key, content do |msg,time,sync|
				# set up handler arguments
				args = block.arity == 2 ? [msg,time,sync,self] : [msg,sync,self]
				# create handler code
				wrapped = proc do |*args|
					host = args.pop
					sync = args.pop
					# call user-specified handler in sandbox
					$SAFE = config.safe_level
					block.call *args
				end
				# start the wrapped handler in the calling environment
				res = env.start_safe sync, wrapped, *args
				begin
					if res && sync
						res = msg(*res) if res.is_a? Array
						send_to :async, args[0].sender,
							res.wrap(:sync_response, :sync_id => sync)
					end
				rescue
					@logger.log_err $!
				end
			end
		end

		# attempt to send a synchronous message
		# multiple times, until success or the
		# maximum tries are reached.
		def try_to_send(&block)
			tries = 0
			while true
				reply = yield
				return reply if reply
				tries += 1
				return nil if tries >= @config.max_send_tries
			end
		end

		# schedule a signal to be sent soon
		def schedule_signal(mode, res, signal, args)
			@signals << [mode, res, signal, args]
		end

		# send a signal to a script handler
		# if synchronous, wait for response
		# if exclusive, stop after first handler
		def send_signal(name, sync, exclusive, *args)
			@logger.dbg "#{info.address.inspect} signal #{name}: begin"
			# try sending to any existing handlers
			@handlers[name] ||= [[], @environments[0..-1]]
			found = false
			@handlers[name][0].each do |env|
				res = signal_on env, name, sync, args
				if exclusive
					@logger.dbg "#{info.address.inspect} signal #{name}: end"
					return [true, res]
				end
				found = true
			end
			# try new scripts as handlers
			until @handlers[name][1].empty?
				env = @handlers[name][1].shift
				if env.handles? name
					@handlers[name][0] << env
					res = signal_on env, name, sync, args
					if exclusive
						@logger.dbg "#{info.address.inspect} signal #{name}: end"
						return [true, res]
					end
					found = true
				end
			end
			@logger.dbg "#{info.address.inspect} signal #{name}: end"
			[found, res]
		end

		# send a signal to a script; not synchronous or required
		def signal(name, *args)
			send_signal name, false, false, *args
		end

		# send a signal to just one script; not sync, but required
		def signal1(name, *args)
			found, res = send_signal name, false, true, *args
			raise "no handlers for #{name}" unless found
			nil
		end

		# raise async signal which MUST be handled
		def signal!(name, *args)
			found, res = send_signal name, false, false, *args
			raise "no handlers for #{name}" unless found
			nil
		end

		# raise sync signal (must be handled)
		def signal?(name, *args)
			found, res = send_signal name, true, true, *args
			raise "no handlers for #{name}" unless found
			res
		end

		# send a signal to an environment
		def signal_on(env, name, sync, args)
			block = proc do |env|
				env.send "on_#{name}", *args
			end
			env.start_safe sync, block, env
		end

		# send a message to another host
		def send_to(mode, host, msg, *args)
			begin
				u = MV::Util.random_uid()
				msg.message_id = next_message_id unless msg.message_id
				host = directory.lookup!(host) unless host.kind_of? HostInfo
				puts "host #{short}: #{u} (1), mode = #{mode}, msg = #{msg.key}"
				reply = send_to_host mode, host, msg, *args
				puts "host #{short}: #{u} (2), mode = #{mode}, msg = #{msg.key}, class = #{reply.class}"
				if mode == :sync && reply && config.do_exchanges
					signal :exchange, host, true 
				end
				# TODO: add non-initiator exchange signal
				reply
			rescue
				@logger.puts $!
				@logger.log_err $!
				return nil
			end
		end

		# send a message to another host.
		# handles security automatically.
		def send_to_host(mode, host, msg, secure=false)
			# secure the message
			if secure
				msg = msg.secure :rsa, host.uid, @keyring
				msg.message_id = next_message_id
			end
			# transmit the message
			msg.sender = uid
			reply = @net.transmit mode, host.address, msg
			return reply if mode == :async
			# try to decrypt sync responses
			if reply
				reply = reply.decrypted @keyring if secure and reply.secure?
			end
			reply
		end

		# create a message with default protocol
		def msg(*args)
			msg_with @protocol, *args
		end

		# creat a message with some protocol
		def msg_with(protocol, *args)
			msg = Message.new protocol, *args
			msg.message_id = next_message_id
			msg.sender = self.uid
			msg
		end

		# increment message id
		def next_message_id
			@last_message_id += 1
		end
	end
end


if $0 == __FILE__
	MV::P2P::Host.new.run
end
