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
require 'thread'
require 'gserver'
require 'util/safe'

module MV::Net

	# The network server is a general-purpose message queue.
	# It allows code to register message templates with active
	# code blocks (or, they can reserve the messages and poll
	# for them). The only bonus functionality is that given a
	# set of default keyrings, it will attempt to handle
	# secure channels automatically. Also, it automates the
	# single echange of a request/response synchronous message.
	class Server < GServer

		extend MV::Util::SafeErrors

		attr_reader :thread

		# intiailize, but do not start server
		def initialize(host)
			@mv_host = host
			@res_mutex = Mutex.new
			@buf_mutex = Mutex.new
			@chunk_mutex = Mutex.new
			@caught_mutex = Mutex.new
			@reservations = {}
			@buffer = []
			@chunks = []
			@keyrings = {}
			@caught = []
			@log = host.logger :net
			@do_sync = true
			super(@mv_host.config.port)
		end

		# set the owner
		def owned_by(host)
			@mv_host = host
			self
		end

		# transmit a message either sync or async (no security at
		# this stage)
		def transmit(mode, address, msg)
			send "transmit_#{mode}", address, msg
		end

private

		# transmit a message and wait for a matching reply
		def transmit_sync(address, msg)
			# wrap the message
			id = MV::Util.random_uid
			msg = @mv_host.msg_with msg.protocol, :sync_message,
				:payload => msg.marshal, :sync_id => id
			# send and wait for response
			reply = wait(:sync_response, {:sync_id => id}) do
				transmit_async address, msg
			end
			# unwrap response
			reply = reply.unwrap(msg.protocol) if reply
		end

		# transmit a message asyncrhonously by sending
		# a doubleword message size, followed by the
		# actual message.
		def transmit_async(address, msg)
			# if address is local, don't much around with sockets
			if address == :local
				receive_chunk msg.marshal
				return
			end

			# try to get a socket
			begin
				socket = TCPSocket.new *address
			rescue Errno::EADDRINUSE => e
				retry
			end

			# send the message header
			text = msg.marshal
			size = text.size
			socket.write([size].pack('I'))

			# send the message and close the socket
			socket.write text
			socket.flush
			socket.close
		end

		# main handling function; read message and
		# add it the the incoming chunks
		def serve(io)
			size = io.read(4).unpack('I')[0]
			text = io.read size
			receive_chunk text
		end

		# render network statistics
		def stats
			"\n\tchunks: #{@chunks.size}" +
			"\n\tbuffer: #{@buffer.size}" +
			"\n\tcaught: #{@caught.size}" +
			"\n\treservations: #{@reservations.inspect}" +
			"\n\tkeyrings: #{@keyrings.size}"
		end

		# log statistics as debug message
		def log_stats
			@log.dbg stats
		end

		# decide whether to log statistics
		def log_stats?
			log_stats if (rand(100) == 0)
		end

		# in debug mode?
		def debug?
			@mv_host.debug?
		end

		# synchronize the given mutex for the duration
		# of the block
		def sync(mutex, &block)
			if @do_sync
				mutex.synchronize &block
			else
				yield
			end
		end

		# receive a new chunk of incoming text
		def receive_chunk(text)
			log_stats?
			sync @chunk_mutex do
				@chunks << text
			end
		end

	public

		# start the server; this function will return.
		# the main processing thread joins with the network thread.
		# start will call main() in this thread.
		def start(*args)
			super(*args)
			start_handler
		end

		# start the dispatcher thread (this function will not block)
		def start_handler
			@thread = Thread.new(self) do |net|
				net.send :main
				net.send :join
			end
		end

		# attempt to shut down the server. if it does not
		# shut down gracefully, force a stop after a fixed
		# amount of time. this function will not return
		# until all server threads are finished.
		def shutdown
			super
			Thread.new(self, @mv_host) do |net,host|
				sleep host.config.shutdown_timeout
				net.stop
				@thread.join if @thread
			end.join
		end

	private

		# the main loop. it decodes chunks of incoming text as
		# messages, dispatches any matching reserved templates,
		# and deletes messages of a certain age that have not
		# been handled.
		def main
			until @shutdown
				begin
					decode_chunks
					dispatch_messages
					decay_messages
					Thread.pass
				rescue
					@log.log_err $!
				end
			end
		end

		# decode chunks into messages. i don't do this in
		# serve() because it is possibly very slow.
		def decode_chunks
			while (chunk = get_chunk)
				buffer Message.unmarshal(@mv_host.protocol, chunk)[0]
			end
		end

		# get the next buffered chunk
		def get_chunk
			sync @chunk_mutex do
				@chunks.shift
			end
		end

		# dispatch available messages to any code that
		# is waiting for them. for reservations without blocks,
		# place the messages on the @caught array.
		def dispatch_messages
			# for each buffered message
			buffered(true) do |msg,time|

				# debug log
				@log.dbg "#{@mv_host.short} got message #{msg.key}"

				# decrypt if a keyring is available
				if msg.encrypted?
					keyring = @keyrings[msg.recipient]
					msg = msg.decrypted keyring if keyring
				end

				# handle sync messages
				if msg.key == :sync_message
					remove = dispatch msg.unwrap, time, msg.sync_id

				# handle normal messages
				else
					remove = dispatch msg, time, nil
				end

				# remove the message if it was handled
				remove
			end
		end

		
		# dispatch a message to any registered handler
		def dispatch(msg, time, sync)

			# get possible reservations
			arr = @reservations[msg.key]
			return false unless arr

			# check reservations against content
			arr.each do |content,res|
				reserved, block = res
				next unless reserved

				# message matched; send it
				if msg.matches? nil, content
					if block
						# block was given: start handler
						thread = Thread.new(msg,time,sync,&block)
						return true
					else
						# no block given: add to caught array
						self.send :sync, @caught_mutex do
							@caught << msg
						end
						return true
					end
				end
			end
			
			# no handlers: return false
			return false
		end

		# delete old messages
		def decay_messages
			buffered(true) do |msg,time|
				(Time.now - time) > @mv_host.config.decay_time
			end
		end

		# iterate all currently buffered messages.
		# depending on the first parameter, will either stop
		# after first matching message, or iterate all messages.
		# the return value of the given block is true iff the
		# last message should be removed from the queue.
		def buffered(all=false, &block)
			returned = nil
			sync @buf_mutex do
				@buffer.each_with_index do |entry,index|
					if yield *entry
						returned = @buffer.delete_at index
						break unless all
					end
				end
			end
			returned
		end

		# like buffered, but operates on @caught array.
		def intercepted(all=false, &block)
			returned = nil
			sync @caught_mutex do
				@caught.each_with_index do |entry,index|
					if yield *entry
						returned = @caught.delete_at index
						break unless all
					end
				end
			end
			returned
		end

		# add a message to the buffer (safe)
		def buffer(msg, time=Time.now)
			sync @buf_mutex do
				@buffer << [msg, time]
			end
		end

	public

		# reserve a message template and wait until
		# that message is received. this operation will
		# time out according to configured parameters.
		def wait(key, content={}, &block)

			# add reservation
			reserved = reserve key, content
			raise "wait key #{key} already reserved" unless reserved
			yield if block

			# wait until timed out
			timeout do
				found = nil

				# scan the caught array
				intercepted do |msg,time|
					if msg.matches? key, content
						unreserve key, content
						found = msg
						true
					else
						false
					end
				end
				return found if found
			end

			# remove reservation
			unreserve key, content
			nil
		end

		# repeatedly try some operation, with a configured wait in
		# between tries, until some maximum timeout interval.
		def timeout(&block)
			start = Time.now
			while true
				yield
				# wait for a given interval (a zero interval is the
				# same as a thread pass)
				interval = @mv_host.config.timeout_interval
				if interval == 0
					Thread.pass
				else
					sleep interval
				end
				# stop trying after timeout
				if (Time.now - start) > @mv_host.config.timeout_maximum
					puts "#{@mv_host.short}: timed out"
					break
				end
			end
		end

		# add an automatic security keyring
		def add_keyring(keyring)
			@keyrings[keyring.uid] = keyring
		end

		# remove an autmatic security keyring (by uid of its owner)
		def remove_keyring(uid)
			@keyrings.delete uid
		end

		# reserve a message template. the key is the type of message,
		# and the content is a (possibly recursive) hash of values
		# which must match (see protocol/object.rb). if a block is given,
		# it will be called with the message and the time at which it
		# is received, for every such message intercepted. otherwise,
		# the message is removed from the queue and placed in the caught
		# array. this function returns true if the reservation is made
		# successfully.
		def reserve(key, content={}, &block)
			sync @res_mutex do
				return false if reserved? key, content
				@reservations[key] ||= {}
				@reservations[key][content] = [true, block]
			end
			true
		end

		# remove an existing reservation
		def unreserve(key, content)
			sync @res_mutex do
				@reservations[key] ||= {}
				@reservations[key].delete content
			end
		end

		# check if the given key/content pair is already reserved
		def reserved?(key, content)
			@reservations[key] ||= {}
			@reservations[key][content]
		end

		# make some methods safe for errors
		safe :transmit, :main, :wait, :timeout, :serve

	end

end
