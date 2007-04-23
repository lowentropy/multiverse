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


# this script handles miscellaneous host-related
# services


script.name = "host"
script.uid = "F2B90EF9AD856866"
script.author = "lowentropy@gmail.com"


# declare (publish) the host's identification resource
fun :on_declare_self do
	info = host.info.pack.inspect
	signal! :publish, host.uid, host.uid, info, false, 'add_host'
end

# declare host, and wait for publish to finish
fun :on_declare_self! do
	info = host.info.pack.inspect
	signal? :publish!, host.uid, host.uid, info, false, 'add_host'
end

# cache a host: add to the directory
fun :on_add_host do |item|
	info = MV::P2P::HostInfo.unpack(item.data)
	host.directory << info
end

# host services are stateless
state :default do
	fun(:start) {exit}
end
