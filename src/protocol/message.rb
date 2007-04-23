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

require 'includes'
require 'protocol/object'


module MV::Protocol

	# a message is a node object which is used to
	# pass information around a network marshalled
	# according to a predefined protocol. Messages
	# also know how to secure themselves.
	class Message < NodeObject

		def initialize(protocol, key, content={}, &block)
			super(protocol, protocol.find_by_type(:message, key)) {}
			set_attributes content
			yield self if block
		end

		# unmarshal a new message of the given protocol
		def self.unmarshal(protocol, data)
			idx = data.index '!'
			key, data = data[0,idx], data[idx+1..-1]
			msg = Message.new protocol, key.to_sym
			msg.unpack data
			[msg, data]
		end

		# helper to wrap a message by setting :payload to the
		# marshalled value of the sub-message
		def self.wrap(protocol, key, msg, content={}, &block)
			content[:payload] = msg.marshal
			Message.new protocol, key, content, &block
		end

		# type of message (key of message node)
		def key
			node.key
		end

		def wrap(key, content={}, &block)
			Message.wrap(@protocol, key, self, content, &block)
		end

		# unwrap message by unmarshalling from :payload
		def unwrap(protocol=@protocol)
			raise "not a wrapped message" unless payload
			Message.unmarshal(protocol, payload)[0]
		end

		# find out if this message matches a template
		def matches?(key, content)
			return false unless node.key == key or key.nil?
			content.each do |key,value|
				begin
					obj = send key
					if NodeObject === obj
						return false unless obj.matches? nil, value
					else
						return false unless obj == value
					end
				rescue
					return false
				end
			end
			true
		end

		# secure the message with the given method (currently only :rsa)
		def secure(method, *args)
			send "secure_#{method}_to", *args
		end

		# clone with some new properties set
		def clone_with(props={})
			obj = clone
			obj.set_to props
			obj
		end

		# secure the message by wrapping it in an rsa
		# message to the given recipient
		def secure_rsa_to(recipient, keyring)
			data = clone_with(:encrypted => true).marshal
			secure = keyring.encrypt_to! recipient, data
			Message.new @protocol, :secure_message,
				{	:mode => {:public => {}},
					:payload => secure, :recipient => recipient }
		end

		# sign the message from the given sender
		def signed(sender, keyring)
			data = clone_with(:signed => true).marshal
			signed = keyring.sign! sender, data
			Message.new @protocol, :signed_message,
				{	:signer => sender, :payload => signed }
		end

		# unsign the message (raise error if it's invalid)
		def unsigned(keyring)
			text = keyring.unsign!(signer, payload)
			raise "invalid signature from #{signer}" unless text
			Message.read @protocol, text
		end

		# decrypt a messag addressed to the owner of the keyring
		def decrypted(keyring)
			Message.read @protocol, keyring.decrypt!(payload)
		end

		# read a message of the given protocol and return it
		def self.read(protocol, data)
			self.unmarshal(protocol, data)[0]
		end

		# returns true if this is an encrypted message (wrapper)
		def encrypted?
			node.key == :secure_message
		end

		# returns true if this is an encrypted message (payload)
		def secure?
			self.encrypted
		end

		# the message type has no object value
		def pack_special(key, value)
			return '' unless value
			return '' if key == :message
			raise "illegal value to pack: #{value} of type #{value.class}"
		end

		# the message type has no object value
		def unpack_special(key, data)
			return [nil, data] if key == :message
			raise "illegal data to unpack: #{data}"
		end
	end

end
