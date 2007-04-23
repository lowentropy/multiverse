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


host = Host.new
host.start
host.net.add_keyring host.keyring

msg = host.msg :chat, {:text => ('t'*1000)}
msg = msg.secure :rsa, host.uid, host.keyring
host.send_to :async, host.uid, msg

host.net.reserve :chat do |msg,time|
	puts "message received at #{time}:"
	puts "text: #{msg.text[0..20]}"
end

puts "going to sleep..."
sleep 3

puts "sending shutdown..."
host.shutdown

puts "all done."
