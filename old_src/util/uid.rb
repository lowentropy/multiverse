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


#
# At 1 new UID per second, there is an 84% chance that
# no UIDs will collide for at least 100 billion years.
#


module MV::Util

	# generate a random 64-bit number, rendered
	# as a 16-character hex string
	def self.random_uid
		'%016X' % [rand(2 ** 64)]
	end

end


if $0 == __FILE__
	uid = MV::Util.random_uid
	if ARGV[0] == '-b'
		puts uid.to_bitstring
	else
		puts uid
	end
end
