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


listen :resend_chunk do |msg|
	uid, seq = msg.uid, msg.sequence_id
	chunk = script.spool.outgoing_chunk(uid, seq)
	if chunk
		msg(	:resend_chunk_ack, :uid => uid,
					:sequence_id => seq, :data => chunk,
					:status => sent)
	else
		msg(	:resend_chunk_ack, :uid => uid,
					:sequence_id => seq, :status => :not_sent)
	end
end

listen :chunks do |msg|
	signal :new_stream, msg.uid, msg.num_chunks, msg.sender
end

listen :chunk do |msg|
	signal :spool, msg.uid, msg.data, msg.sequence_id
end
