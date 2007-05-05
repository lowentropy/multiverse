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


# declare (publish) the host's identification resource
map :host do
private
	# publish host info/credentials
	fun :declare do
		publish :uid => host.uid, :owner => host.uid,
						:content => host.info.marshal,
						:signed => false, :handler => :add_host
	end

public
	# cache a host: add to the directory
	fun :add
		host.directory << Message.unmarshal(params[:host])
	end
end
