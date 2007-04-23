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


# add a seed host
fun :on_add_seed_host do |info|
	grid.seeds << info
	host.directory << info
	dbg "added seed #{info.uid} to #{host.uid}"
end

# remove a seed host
fun :on_remove_seed_host do |uid|
	grid.seeds.reject! do |info|
		info.uid == uid
	end
	host.directory.delete uid
end

fun :publish do |uid,owner,data,signed,sync,*args|
	dbg "#{$env.host.short}: in publish function"
	hosts, chunks, handler = [], grid.should_chunk?(data.size), args[0]
	# construct single cache message
	msg = if handler
		msg(	:cache, :uid => uid, :owner => owner,
					:data => data, :chunks => chunks,
					:data_signed => signed,
					:handler => handler)
	else
		msg(	:cache, :uid => uid, :owner => owner,
					:data => data, :chunks => chunks,
					:data_signed => signed)
	end
	dbg "handler for published content: #{handler}"
	# handlers are pgrid links plus seeds
	targets = grid.handlers(uid) + grid.seed_uids
	# send to each handler host
	targets.each do |ptr|
		# send chunks if data is large
		signal? :send_chunks, uid, ptr, data if chunks
		# send sync and get confirmation
		if sync
			reply = send? :sync, ptr, msg
			next unless reply && reply.key == :cache_ack
			if reply.status.key == :accepted
				hosts << ptr
			elsif reply.status.key == :redirected
				hosts.concat reply.hosts
			end
		# send async, no confirmation
		else
			dbg "sending async publish"
			send? :async, ptr, msg
			dbg "done w/ async send"
		end
	end
	hosts
end

# publish some data via pgrid
fun :on_publish do |uid,owner,data,signed,*args|
	publish uid, owner, data, signed, false, *args
end

fun :on_publish! do |uid,owner,data,signed,*args|
	publish uid, owner, data, signed, true, *args
end

# retrieve data from the network
fun :on_retrieve do |uid|
	dbg "#{host.info.address[0]} trying to retrieve #{uid}"
	# send to seeds if we're supposed to have it
	pointers = grid.seed_uids[0..-1] + grid.handlers(uid)
	tried = []
	until pointers.empty?
		ptr = pointers.shift
		next if tried.include? ptr
		tried << ptr
		dbg "#{host.info.address[0]} trying retrieval of #{uid} from #{ptr}"
		reply = send? :sync, ptr, :uncache, :uid => uid, :chunks => :optional
		next unless reply && reply.key == :uncache_ack
		if reply.status.key == :sent
			data = signal? :uncache, uid
			return data if data
		elsif reply.status.key == :redirect
			pointers.concat reply.hosts
		end
	end
	dbg "#{host.info.address[0]}'s retrieval of #{uid} failed"
	nil
end

# the initiator sends the exchange message
fun :on_exchange do |host,initiator|
	return unless initiator
	send? :async, host, :pgrid_exchange,
		:config => self.grid.config.inspect,
		:depth => 0, :respond => true
end

# do pgrid exchange protocol
fun :on_pgrid_exchange do |host,grid,depth,initiator|
	self.grid.exchange host, grid, depth, initiator
end
