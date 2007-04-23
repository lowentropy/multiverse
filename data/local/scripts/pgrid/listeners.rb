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


# do grid exchange when prompted
listen :pgrid_exchange do |msg|
	grid = k(:PGridHost).load(self.host, eval(msg.config))
	signal! :pgrid_exchange, msg.sender, grid, msg.depth, !msg.respond
	if msg.respond
		send? :async, msg.sender, :pgrid_exchange,
				:config => self.grid.config.inspect,
				:depth => msg.depth, :respond => false
	end
end

# accepts a cache request (sync, though result may not be used).
# this listener first checks whether the grid should handle the
# data, and passes it on if not.
listen :cache do |msg|
	dbg "in cache"
	do_cache = false

	# require signed data for updates or when specified in config
	res = if	(grid.require_cache_sigs? and !msg.data_signed)# or
		#	(grid.have_signed? msg.uid and !msg.data_signed)
		dbg "not signed"
		msg(	:cache_ack, :uid => msg.uid,
					:status => :denied, :reason => :not_signed)

	# obtain data from spool if necessary
	elsif (data = msg.chunks ? unspool(msg.uid) : msg.data).nil?
		dbg "data loss"
		msg(	:cache_ack, :uid => msg.uid,
					:status => :failed, :reason => :data_loss)

	# if we don't handle the UID, pass it along (but cache it too!)
	elsif !grid.handles?(msg.uid)
		dbg "#{$env.host.short}: going to publish #{msg.uid} now"
		hosts = signal? :publish!,	msg.uid, msg.owner, msg.data,
																msg.data_signed, msg.handler
		do_cache = true
		msg(	:cache_ack, :uid => msg.uid,
					:status => :redirected, :hosts => hosts)

	# try to unsign the data
	elsif msg.data_signed && (data = unsign data, msg.owner).nil?
		dbg "can't unsign stuff owned by #{msg.owner}"
		msg(	:cache_ack, :uid => msg.uid, 
					:status => :failed, :reason => :bad_signature)

	# cache it, don't pass anywhere
	else
		do_cache = true
		msg(:cache_ack, :uid => msg.uid, :status => :accepted)
	end

	if do_cache
		# signal the cache and wait for answer
		dbg "going to wait for cache now (#{msg.data_signed})"
		signal? :cache, msg, data
		dbg "done waiting for cache now"
	end

	dbg "end of cache"
	res
end

# do uncache (sync)
listen :uncache do |msg|
	# redirect if we don't handle it
	if !grid.handles? msg.uid
		msg(	:uncache_ack, :uid => msg.uid,
					:status => :redirect, :hosts => grid.handlers(msg.uid))

	# retrieve data from 
	elsif (data = signal?(:uncache, msg.uid))
		msg(	:uncache_ack, :uid => msg.uid,
					:status => :failed, :reason => :cannot_find, :hosts => [])

	else
		# decide whether to chunk it
		if grid.should_chunk? data[0].size, msg.chunks
			# send the chunks
			signal? :send_chunks, msg.uid, msg.requester, data[0]
				
			# send the notice
			send_ :async, msg.requester, :cache,
				:uid => msg.uid, :owner => data[1], :chunks => true,
				:data_signed => data[2], :acknowledge => false

		else
			# send data in one message
			send_ :async, msg.requester, :cache,
				:uid => msg.uid, :owner => data[1], :chunks => false,
				:data_signed => data[2], :acknowledge => false
		end

		# send success message
		msg(:uncache_ack, :uid => msg.uid, :status => :sent, :hosts => [])
	end
end
