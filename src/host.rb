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


# simple host-from-string functionality
class String
	# return a host object
	def to_host
		host, port = split ':'
		Host.new($env, [host, port || 4000])
	end
end

# a Host object is a pointer to some computer or iphone or whatever.
class Host

	attr_reader :info

	# TODO REMOVE ME
	attr_reader :env

	# FIXME the info tuple is dumb
	def initialize(env, info)
		@env, @info = env, info
	end

	def host
		@info[0]
	end
	
	def port
		@info[1]
	end

	# issue a command on the script environment to send
	# an HTTP PUT message.
	def put(url, params={})
		@env << [:put, self, url, params]
		nil
	end

	# host:port
	def to_s
		info.join ':'
	end

end
