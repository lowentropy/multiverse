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
map :pgrid do
	map :seeds do

	private

		fun :add do
			seed = params[:host].to_host
			pgrid.seeds << seed
			host.directory << seed
		end

		fun :delete do
			pgrid.seeds.reject! {|seed| seed.uid == params[:uid]}
			host.directory.delete params[:uid]
		end

	end

private
	
	fun :publish do
		load_params :uid, :owner, :data, :signed, :sync, :handler
		spool = pgrid.should_spool? data.size
		msg = params.reject {|k,v| k == :sync}
		msg.reject! {|k,v| k == :data} if spool
		hosts = []

		targets = pgrid.handlers(uid) + pgrid.seed_uids
		targets.each do |ptr|
			host.post '/spool/send', msg if spool
			if sync
				rep = ptr.post '/pgrid/cache', msg
				case rep[:status]
				when :accepted
					hosts << ptr
				when :redirected
					hosts.concat rep[:hosts]
				end
			else
				ptr.put '/pgrid/cache', msg
			end
		end
		reply :hosts => hosts
	end

	map :retrieve do
		resource(/[0-9A-Fa-f]{16}/) do |uid|
			tried, data = [], nil
			pointers = pgrid.seed_uids[0..-1] + pgrid.handlers(uid)
			until pointers.empty? || data
				ptr = pointers.shift
				next if tried.include? ptr
				tried << ptr
				rep = ptr.post '/pgrid/find', :uid => uid, :spool => :optional
				case rep[:status]
				when :sent
					data = host.get(rep[:spool] ? "/spool/#{uid}" : "/cache/#{uid}")
				when :redirect
					pointers.concat rep[:hosts]
				end
			end
			raise "could not retrieve #{uid}" unless data
			return data
		end
	end

end
