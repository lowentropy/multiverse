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


module MV::P2P

	# host info is a reference to an external host.
	# it can identify by address/port, or by UID
	# alone (in which case a directory must be used)
	class HostInfo
		
		attr_reader :host, :uid

		def initialize(uid, address, port, host=nil, local=false)
			@uid, @address, @port, @host = uid, address, port, host
			@pubkey = host.pubkey if host
			@local = local
		end

		def pack
			{	:uid => @uid,
				:address => @address,
				:port => @port,
				:pubkey => @pubkey	}
		end

		def self.unpack(packed)
			packed = eval packed
			info = HostInfo.new packed[:uid], packed[:address], packed[:port]
			info.instance_variable_set :@pubkey, packed[:pubkey]
			info
		end

		def short
			address.inspect
		end

		# create info reference to local host
		def self.local(host)
			uid = host.config.uid
			address = host.config.address
			port = host.config.port
			HostInfo.new uid, address, port, host, true
		end

		def local?
			@local
		end
		
		def address
			local? ? :local : [@address, @port]
		end

		def not_local!
			@local = false
		end

	end

end
