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


protocol << <<-END

	pgrid_exchange: message
		depth: u8
		config: data
		respond: bool

	cache: message
		uid: uid
		owner: uid
		chunks: bool
		data_signed: bool
		data: optional = data
		handler: optional = string

	cache_ack: message
		uid: uid
		status: option
			accepted
			failed
			denied
			redirected
		reason: optional = option
			data_loss
			bad_signature
			not_signed
			other
		hosts: optional = array
			host: uid

	uncache: message
		uid: uid
		requester: uid
		chunks: option
			forbidden
			optional
			required

	uncache_ack: message
		uid: uid
		status: option
			sent
			failed
			redirect
		reason: optional = option
			cannot_find
			cannot_send
			other
		hosts: optional = array
			host: string

END
