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


