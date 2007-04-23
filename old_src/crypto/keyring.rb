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
require 'openssl'

include OpenSSL
include PKey


module MV::Crypto

	# A keyring store the public and private key of a host or user.
	# It is used for doing RSA encryption/decryption/signing.
	class Keyring

		attr_reader :uid
		
		# load the host or user keys
		def initialize(host, uid=nil)
			@block_len = [245, 256]
			@host = host
			if uid
				@uid = uid
				base = "#{self.base}/config/users/#{uid}"
				@priv = RSA.new File.read("#{base}/user.private.key")
				@pub =  RSA.new File.read("#{base}/user.public.key")
			else
				@priv = RSA.new File.read("#{self.base}/config/local.private.key")
				@pub =  RSA.new File.read("#{self.base}/config/local.public.key")
				@uid = @host.uid
			end
			@keys = {}
		end

		# the base directory to find keys
		def base
			@base ||= File.expand_path(File.dirname(__FILE__) + '/../..')
		end

		# return the public key for the given user. return nil on failure.
		def key_for(uid)
			key = @keys[uid]
			return key if key
			filename = "#{base}/data/keys/#{uid}"
			return nil unless File.exists? filename
			@keys[uid] = RSA.new File.read(filename)
		end

		def pubkey
			@pub.to_s
		end

		# try to get the given user's public key by sending a message
		# asking for it. return nil on failure.
		def retrieve_key(uid)
			@host.signal! :lookup, uid, (data = [])
			Thread.pass while data.empty?
			info = data[0]
			return nil unless info && info.is_a?(Hash)
			@keys[uid] = RSA.new info[:pubkey]
		end

		# get the key for a user, messaging them if need by.
		# raise an error on failure.
		def key_for!(uid)
			key_for(uid) || retrieve_key(uid)
		end

		# encrypt some plaintext to the given host/user.
		def encrypt_to!(uid, text)
			return nil unless (key = key_for! uid)
			split(text, @block_len[0]) do |block|
				key.public_encrypt block
			end
		end

		# sign some plaintext with our private key. embed our UID
		# in the plaintext for verification.
		def sign!(uid, text)
			split(uid + text, @block_len[0]) do |block|
				@priv.private_encrypt block
			end
		end

		def sign(text)
			sign! uid, text
		end

		# unsign (check a signature) with the given public key.
		# returns nil if the signature is invalid (not from the
		# stated user), else return the plaintext.
		def unsign!(uid, crypt)
			return nil unless (key = key_for! uid)
			text = split(crypt, @block_len[1]) do |block|
				key.public_decrypt block
			end

			if text[0,uid.size] != uid
				nil
			else
				text[uid.size..-1]
			end
		end

		# decrypt a message addressed to us
		def decrypt!(crypt)
			split(crypt, @block_len[1]) do |block|
				@priv.private_decrypt block
			end
		end

	private
		def split(text, size)
			i, result = 0, ""
			while i < text.size
				block = text[i,size]
				result << yield(block)
				i += size
			end
			result
		end

	end

end
