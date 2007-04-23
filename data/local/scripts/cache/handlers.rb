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


fun :on_cache do |msg,data|
	signed = msg.data_signed ? msg.data : nil
	if script.cache.put msg.uid, msg.owner, data, signed
		if msg.handler
			signal? msg.handler.to_sym, msg
		end
	else
		"cache failed"
		false
	end
end

fun :on_uncache do |uid|
	puts "in uncache: begin = #{uid.inspect}"
	data = script.cache.get uid
	puts "in uncache: end = #{data}"
	data
end

fun :on_lookup do |uid|
	text = script.cache.get uid
	unless text
		dbg "lookup failed, trying to retrieve"
		text = signal? :retrieve, uid
		dbg "the retrieve returned"
	end
	begin
		eval(text)
	rescue
		text
	end
end

fun :on_query_cache do |uid|
	script.cache.query uid
end

fun :on_dump_cache do
	script.cache.dump
end

fun :on_clear_cache do
	script.cache.clear
end
