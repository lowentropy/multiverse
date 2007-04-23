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


# a ping has fields to remember latency
protocol << <<-END
	ping: message
		send_time: u64 = 0
		recv_time: u64 = 0
END


# send back ping (as in echo), but set time of handling
listen :ping do |msg,time|
	msg.recv_time = time.to_i
	msg
end


# SIGNAL: ping
#
# send a ping to the target and wait for the reply
# optionally takes an array return
fun :on_ping do |target|
	send?(:sync, target, :ping, :send_time => Time.now.to_i)
end


# ping server is stateless (TODO: add latency collection)
state :default do
	fun(:start) {exit}
end
