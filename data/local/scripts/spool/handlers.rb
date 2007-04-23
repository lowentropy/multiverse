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


fun :on_new_stream do |uid,size,host|
	script.spool.stream uid, size, host
end

fun :on_unspool do |uid|
	script.spool.unspool uid
end

fun :on_spool do |uid,data,seq|
	script.spool.spool uid, data, seq
end

fun :on_send_chunks do |uid,host,data|
	size = host.config.chunk_size
	chunks, remaining = [], data
	until remaining.empty?
		chunks, remaining = remaining[0,size], remaining[size..-1]
	end
	send :async, host, :chunks, :uid => uid, :num_chunks => chunks.size
	chunks.each_with_index do |chunk,i|
		send :async, host, :chunk, :uid => uid,
			:sequence_id => i, :data => chunk
	end
	script.spool.cache_outgoing uid, host, chunks
end
