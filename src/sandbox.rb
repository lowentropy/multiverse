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

require 'untrace'

# A sandbox object allows code blocks to run in a
# clean environment; if the blocks have $SAFE = 4,
# they are effectively cut off from the rest of
# the system.
class Sandbox
	include Untrace
	def initialize
		@_delegates = {}
		@_root_delegate = nil
		self.taint
	end
	def sandbox(&block)
		untraced do
			instance_eval &block
		end
	end
	def [](key)
		eval "@#{key}"
	end
	def []=(key, value)
		eval "@#{key} = value"
	end
	def delegate(name, object)
		if name
			@_delegates[name.to_sym] = object
		else
			@_root_delegate = object
		end
	end
	def method_missing(id, *args, &block)
		untraced do
			name = id.id2name.to_sym
			if @_delegates[name]
				@_delegates[name].send name, *args, &block
			elsif @_root_delegate
				@_root_delegate.send name, *args, &block
			else
				super
			end
		end
	end
end


