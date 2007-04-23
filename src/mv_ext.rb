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

# This code is to prevent DOS attacks by hiding some
# builtin methods of Ruby's Thread class:
# critical= and abort_on_exception=.
class ::Thread
	
	# this inner class allows code running at $SAFE==0
	# to access critical=.
	class CritContainer
		def initialize(crit)
			@crit = crit
		end
		def set(*args)
			raise "safe threads can't go critical" if $SAFE > 0
			@crit.call *args
		end
		def instance_variable_get(*args)
			raise "somebody's trying to be naughty!"
		end
	end

	# store the old critical= method into a hidden wrapper
	@@crit = CritContainer.new(method(:critical=))

	# redefine critical= to use the safe wrapper
	def self.critical=(*args)
		@@crit.set *args
	end

	# don't allow any access to abort_on_exception=
	def self.abort_on_exception=(*args)
		raise "somebody's trying to be naughty!"
	end
	def abort_on_exception=(*args)
		raise "somebody's trying to be naughty!"
	end
end


# Fixnums have been extended to pack into and out of byte streams
class Fixnum
	def pack(signed, size)
		packed = ''
		value = self
		value += (2 ** size) if signed and self < 0
		(size >> 3).times do
			packed << [(value & 0xff)].pack('c')
			value >>= 8
		end
		packed
	end
	def self.unpack(signed, str)
		bytes = str.size
		size = bytes * 8
		num = 0
		(str.size-1).downto(0) do |i|
			num = (num << 8) + str[i]
		end
		num -= (2 ** size) if signed and num >= (2 ** (size-1))
		num
	end
end


# Symbols have a handy capitalize, i.e. :abcd -> :Abcd
class Symbol
	def capitalize
		to_s.capitalize.to_sym
	end
end


# Strings have numeric accessors and UID conversion added
class String

	# true for a positive or negative numeric integer
	def numeric?
		self.to_i.to_s == self
	end

	# true for uids
	def uid?
		return false unless size == 16
		0.upto(15) do |i|
			return false unless "0123456789ABCDEF".include? self[i,1]
		end
		true
	end

	# convert uid to bitstring
	def to_bitstring
		"%064b" % [eval("0x#{self}")]
	end

	# convert bitstring to uid
	def to_uid
		"%016X" % [eval("0b#{self}")]
	end
end
