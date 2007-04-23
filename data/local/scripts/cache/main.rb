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


require 'cache/cache'
require 'cache/handlers'

script.name = "cache"
script.uid = "3A4E6040D292B96B"
script.version = "0.0.1"
script.author = "lowentropy@gmail.com"

var :cache

fun :setup do |config|
	script.cache = k(:DataCache).new config
end

fun :teardown do |config|
	config.clear if script.cache.cleared?
	config.merge! script.cache.delta
end

state :default do
	fun :start do
		Thread.pass
		#sleep host.config.cache_clean_interval
		#script.cache.clean
	end
end
