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

require 'spool/protocol'
require 'spool/spool'
require 'spool/handlers'
require 'spool/listeners'
require 'spool/handlers'

script.name = "spool"
script.uid = "827E1B7E10AFDEC9"
script.version = "0.0.1"
script.author = "lowentropy@gmail.com"

var :spool

fun :setup do
	script.spool = new :DataSpool
end

fun :teardown do
	script.spool.clear
end

state :default do
	fun :start do
		sleep host.config.cache_clean_interval
		script.spool.clean
	end
end
