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


script.name = "p2p.pgrid"
script.version = "0.0.1"
script.uid = "4C2B7845C70DCBCF"

require 'pgrid/protocol'
require 'pgrid/host'
require 'pgrid/listeners'
require 'pgrid/handlers'
require 'spool/util'


# the core script variable: a pgrid host
var :grid

# setup: read grid from config file
fun :setup do |config|
	self.grid = k(:PGridHost).load host, config
end

# teardown: write grid to config file
fun :teardown do |config|
	config.merge! grid.config
end


# default state: does nothing
state :default do
	fun :start do
		exit
	end
end
