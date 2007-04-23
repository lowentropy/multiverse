#! /usr/bin/ruby

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


$: << File.expand_path(File.dirname(__FILE__) + '/..')

require 'includes'
require 'p2p/host'

include MV::P2P


num = (ARGV[0] || 300).to_i

host = Host.new
host.load 'echo'
host.config.do_exchanges = false
host.config.debug = false
host.start

sleep 3
interval = 100

begin
	puts "starting"
	start = Time.now
	last_time = start

	num.times do |i|
		sig = "test #{i}"
		reply = host.signal? :echo, host.uid, sig
		raise "bad response '#{reply}' != '#{sig}'" unless reply == sig
		if (i + 1) % interval == 0
			puts (Time.now - last_time).to_f / interval
			last_time = Time.now
		end
	end

	elapsed = Time.now - start
	puts "\n\nTotal: #{elapsed} sec"
	puts "Each: #{elapsed.to_f / num} sec"

ensure
	host.shutdown
end
