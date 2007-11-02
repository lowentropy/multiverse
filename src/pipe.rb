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

require 'message'
require 'thread'


# Objects to be sent over pipe should have marshal
# methods. An unmarshal block should be passed to
# the pipe constructor.
class ObjectPipe

	# attach the pipe to in/out streams, stdin/out by default
	def initialize(input=$stdin, output=$stdout, &unmarshal)
		@in, @out, @unmarshal = input, output, unmarshal
		@read, @write = Mutex.new, Mutex.new
	end

	# read a message. blocks until an entire message
	# can be read. raises errors on malformed streams.
	# returns nil at EOF.
	def read
		return nil unless @in
		begin
			@read.synchronize do
				sep = @in.read 10
				return nil if !sep or sep.empty?
				raise "separator was '#{sep}'" unless sep == "---------\n"
				len = @in.readline.strip.to_i
				text = @in.read len
				term = @in.read 10
				raise "terminator was '#{term}'" unless term == "---------\n"
				@unmarshal.call text
			end
		rescue EOFError => e
			nil
		end
	end

	# write an object to the pipe. by default, flush after.
	def write(object, flush=true)
		return unless @out and not @out.closed?
		text = object.marshal
		@write.synchronize do
			@out.puts "---------"
			@out.puts text.size.to_s
			@out.write text
			@out.puts "---------"
			@out.flush if flush
		end
	end

	# close the in/out streams
	def close
		@in.close unless @in.closed?
		@out.close unless @out.closed?
	end

	def closed?
		@in.closed?
	end
end


# Message pipe just passes static unmarshal method to constructor.
class MessagePipe < ObjectPipe
	def initialize(input=$stdin, output=$stdout)
		super(input, output) do |text|
			Message.unmarshal text
		end
	end
end


# Buffer is a mutex-synchronized subclass of Array.
# Locks mutex on <<, [], []=, shift, push, pop, empty?, and clear.
# TODO test me
class Buffer < Array
	def initialize(*args)
		@mutex = Mutex.new
		super(*args)
	end
	%w(<< [] []= shift push pop empty? clear).each do |method|
		define_method method do |*args|
			@mutex.synchronize do
				super *args
			end
		end
	end
end


# Message pipe in memory; doesn't use byte-based streams at all.
class MemoryPipe < MessagePipe
	attr_accessor :id, :debug
	# input and output should be some type of buffer
	def initialize(input, output)
		super(input, output)
		@closed = false
		@debug = false
	end
	# if debugging is on, prints a message when it is received
	def dbg_read(msg)
		return unless @debug
		puts "READ #{msg.command}: #{msg.id}" if msg.respond_to? :command
	end
	# if debugging is on, prints a message when it is sent
	def dbg_wrote(msg)
		return unless @debug
		puts "WROTE #{msg.command}: #{msg.id}" if msg.respond_to? :command
	end
	# read a message from the input buffer. will block until a
	# message is available. returns an eof exception if the pipe
	# has been closed. on receiving the message :eof, will close
	# and return nil.
	def read
		raise IOError.new("eof") if @closed
		Thread.pass while @in.empty?
		msg = @in.shift
		dbg_read msg
		if msg == :eof
			puts "READ EOF" if @debug
			@closed = true
			return nil
		end
		msg
	end
	def closed?
		@closed
	end
	# write a message to the pipe (note that flushing does nothing).
	def write(object, flush=true)
		@out << object
		dbg_wrote(object)
	end
	# close the write end of the pipe by sending :eof
	def close
		@out << :eof
		puts "WROTE EOF" if @debug
	end
end
