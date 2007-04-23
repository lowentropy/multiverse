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


$: << File.expand_path(File.dirname(__FILE__) + "/..")

require 'util/uid'
require 'protocol/parser'
require 'protocol/protocol'
require 'protocol/message'
include MV::Protocol

parser = Parser.new
protocol = Protocol.new(false)
groups = parser.read_and_parse "#{ROOT}/config/protocol"
nodes = parser.compile protocol, groups
nodes.each {|n| n.register_all :message}

uid0 = MV::Util::random_uid
uid1 = MV::Util::random_uid
uid2 = MV::Util::random_uid
uid3 = MV::Util::random_uid


msg = Message.new(protocol,
	:chat,
	{	:sender => uid3,
		:message_id => 1,
		:text => 'foo'})

sec = Message.new(protocol,
	:signed_message,
	{	:sender => uid3,
		:message_id => 2,
		:signer => uid2,
		:payload => msg.marshal })

msg.print
sec.print
secm = sec.marshal
puts secm
sec = Message.unmarshal(protocol, secm)[0]
sec.print
msg = Message.unmarshal(protocol, sec.payload)[0]
msg.print
