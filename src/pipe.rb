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


# Objects to be sent over pipe should have marshal
# and unmarshal methods
class ObjectPipe
	def initialize(input=$stdin, output=$stdout, &unmarshal)
		@in, @out, @unmarshal = input, output, unmarshal
	end
	def read
		return nil unless @in
		begin
			len = @in.readline.to_i
			text = @in.read len
			@unmarshal.call text
		rescue EOFError => e
			nil
		end
	end
	def write(object)
		return unless @out
		text = object.marshal
		@out.puts text.size
		@out.write text
		@out.flush
	end
	def close
		@in.close
		@out.close
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


