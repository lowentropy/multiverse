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
require 'script/compiler'
require 'p2p/info'

include MV::Script

module MV::P2P

	# the directory maintains an active index of hosts
	# by their uid.
	class Directory

		def initialize(host)
			@host = host
			@hosts = {}
		end

		# add an element to the directory
		def []=(uid, value)
			raise "illegal host" unless value.is_a? HostInfo
			@hosts[uid] = value
		end

		def <<(info)
			self[info.uid] = info
		end

		def delete(uid)
			@hosts.delete uid
		end

		# find item by uid, returning nil on failure
		def lookup(uid)
			@hosts[uid]
		end

		# find item by uid, raising error on failure
		def lookup!(uid)
			item = lookup uid
			raise "cannot find uid #{uid}" unless item
			item
		end

	end

end
