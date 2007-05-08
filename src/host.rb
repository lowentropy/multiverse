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


$: << File.dirname(__FILE__)


class String
	def to_host
		Host.new($env, self)
	end
end

class Symbol
	def to_host
		to_s.to_host
	end
end


class Host

	def initialize(env, info)
		@env, @info = env, info
	end

	def put(url, params={})
		@env.outbox << [:put, @info, url, params]
		nil
	end

	def post(url, params={})
		response = {}
		status = []
		@env.outbox << [:post, @info, url, params, response, status]
		@env.pass until status.any?
		(status = status[0]) == :ok ? response[0].params : raise(status)
	end

	def get(url, params={})
		response = []
		status = []
		@env.outbox << :get, @info, url, params, response, status]
		@env.pass until status.any?
		(status = status[0]) == :ok ? response[0][:data] : raise(status)
	end

end
