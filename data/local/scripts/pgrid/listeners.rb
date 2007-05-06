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


map :pgrid do

	# do grid exchange when prompted
	fun :exchange do
		load_params :sender, :depth, :respond
		grid = k(:PGridHost).load(host, eval(params[:pgrid]))
		pgrid.exchange sender.to_host, grid, depth, !respond
		if respond
			sender.put '/pgrid/exchange',
				:pgrid => pgrid.config.inspect,
				:depth => depth,
				:respond => false
		end
	end

	# accepts a cache request (sync, though result may not be used).
	# this listener first checks whether the grid should handle the
	# data, and passes it on if not.
	fun :cache do
		load_params :uid, :chunks, :data, :signed, :owner

		# require signed data for updates or when specified in config
		if (pgrid.require_cache_sigs? and signed)# or
			reply :uid => uid, :status => :denied, :reason => :not_signed

		# obtain data from spool if necessary
		elsif (data = chunks ? host.get("/spool/get/#{uid}") : data).nil?
			reply :uid => uid, :status => :failed, :reason => :data_loss

		# if we don't handle the UID, pass it along (but cache it too!)
		elsif !grid.handles?(msg.uid)
			hosts = host.post('/pgrid/publish', params)[:hosts]
			reply :uid > uid, :status => :redirected, :hosts => hosts
			host.post '/cache/update', params if do_cache

		# try to unsign the data
		elsif signed && (data = unsign data, owner).nil?
			reply :uid => uid, :status => :failed, :reason => :bad_signature

		# cache it, don't pass anywhere
		else
			reply :uid => uid, :status => :accepted
			host.post '/cache/update', params if do_cache

		end

		# signal the cache and wait for answer
	end

	# get cached data
	fun :find do
		load_params :uid, :requester, :chunks

		if !pgrid.handles? uid
			reply :uid => uid, :status => :redirect, :hosts => pgrid.handlers(uid)

		elsif !(item = host.post('/cache/get', :uid => uid))[:found]
			reply :uid => uid, :status => :failed, :reason => :cannot_find

		else
			if pgrid.should_chunk? item.data.size, chunks
				host.post '/spool/send',
					:uid => uid, :host => requester, :data => item.data
				reply :uid => uid, :status => :sent, :spooled => true,
					:signed => item.signed, :owner => item.owner

			else
				reply :uid => uid, :status => :sent, :owner => item.owner,
					:data => item.data, :spooled => false, :signed => item.signed
			end
		end
	end
end
