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


module MV::Protocol

	# Node is fairly complicated and hackish, but that
	# is the nature of something so meta...
	# It's purpose is to represent a tree of templates,
	# each having a key, a type, and optionally a value,
	# with sub-entries forming the "type" of the template.
	class Node

		attr_reader :key, :type, :value
		
		# Parse line of text toget key, typename, value.
		# then iterate sub-entries and intiialize those
		# nodes. Types inherit attributes of base type,
		# and non-types instantiate value to defaults given
		# by type. Value is interpreted by type.
		# NOTE: don't give default values for arrays. ouch.
		#
		# If head is nil, will return after setting @protocol.
		# (private behavior for creating the type-type)
		def initialize(protocol, default, head, sub)
			@protocol = protocol
			return unless head

			# parse line in format "key [: type [= value]]"
			match = /\A(\w+)\s*(:\s*((\w+)\s*(=\s*(.+))?)?)?\Z/.match head
			raise "malformed node: #{head} (nil=#{head.nil?})" unless match

			@key = match[1].to_sym

			# try to find the node's type
			begin
				@value = match[6]
				@type = \
					if match[4].nil?
						raise "no known type for #{head}" if default.nil?
						protocol.find_type default
					else
						protocol.find_type match[4]
					end

				# interpret value by new type
				@value = @type.interpret @value
			rescue Exception => e
				puts "error on line: #{head}"
				raise e
			end

			# inherit from base type and instantiate entries
			@entries = {}
			inherit if is_type? or is_optional?
			instantiate

			# create sub-entries
			sub.each do |set|
				node = Node.new protocol, subtype, *set
				@entries[node.key] = node
			end

			# update protocol's set of types
			@protocol.update_type(@key, self) if is_type?
		end

		# string helper
		def to_s
			key.to_s
		end

		# inherit attributes from base type (@value) if we're a type
		def inherit
			raise "inheritance of non-type" unless is_type? or is_optional?
			return unless value
			value.each do |key,value|
				@entries[key] = value
			end
		end

		# add entries which are defined by default in type
		def instantiate
			@type.each do |key,value|
				@entries[key] = value
			end
		end

		# recursive node tree printing
		def print(pre='')
			puts "#{pre}#{key} : #{type.key} = #{value}"
			each do |key,value|
				value.print(pre+'  ')
			end
		end

		# set attributes on this node with a similarly-formatted node
		def update_with(other)
			other.each do |key,value|
				@entries[key] = value
			end
		end

		# register this node with the protocol
		def register
			@protocol.register type.key, key, self
		end

		# recursively register nodes of a given type
		def register_all(type)
			register if self.type.key == type
			@entries.each {|k,node| node.register_all type}
		end

		# some nodes have default sub-types
		def subtype
			sub = if is_type?
				if @value
					@value.subtype
				else
					self[:subtype]
				end
			elsif is_optional?
				@value.subtype
			else
				@type.subtype
			end
			return sub.value if sub.is_a? Node
			sub
		end

		# iterate each node entry by key, node
		def each(&block)
			@entries.each &block
		end

		# return named entry
		def [](key)
			@entries[key.to_sym]
		end

		# is this node a type? (is it's type the type-type?)
		def is_type?
			type.is_type_type?
		end

		# is this an 'optional' node? (behaves like it's value (a type))
		def is_optional?
			type.key == :optional
		end

		# the type-type is a special node instance
		def is_type_type?
			@type_type
		end

		# create a type of a given key (used only for type-type)
		def self.type(protocol, key)
			node = Node.new protocol, nil, nil, nil
			node.make_type key
		end

		# instantiate regular node values with type-specific stuff
		def make_type(key)
			if key == :type
				@type_type = true
				@type = self
			else
				@type_type = false
				@type = @protocol.find_type :type
			end
			@key = key
			@value = nil
			@entries = {}
			self
		end

		# is this type simple? like integers, floats, etc.
		def simple?
			raise "non-type is not simple" unless is_type?
			[:u8,:u16,:u32,:u64,:s8,:s16,:s32,:s64,:f32,:f64,
			 :string,:date,:version,:data,:bool,:uid,:sid].include? key
		end

		# interpret a given value by this node type.
		# formats and converts strings, etc. as appropriate.
		def interpret(value, sub_entry=nil)
			raise "non-type #{key} can't interpret #{value}" unless is_type?
			return nil if value.nil?

			case key
			when :u8,:u16,:u32,:u64
				i = value.to_i
				raise "unsigned number less than zero" if i < 0
				i

			when :s8,:s16,:s32,:s64
				value.to_i

			when :f32,:f64
				value.to_f

			when :string
				value

			when :date, :version, :data, :uid, :sid
				value

			when :array
				value.map do |v|
					if v.is_a? NodeObject
						v
					else
						NodeObject.new(@protocol, sub_entry).set_to v
					end
				end

			when :bool
				case value.to_s.downcase
					when 'true' then true
					when 'false' then false
					else raise "invalid boolean value #{value}, class = #{value.class}"
				end

			when :message, :option
				nil

			when :type, :optional
				@protocol.find_type value

			else
				raise "unknown format #{key} for #{value}"

			end
		end

		# flatten into basic value or hash
		def flatten
			if @type.simple?
				value
			else
				hash = {}
				@entries.each do |k,v|
					hash[k] = v.flatten
				end
				hash
			end
		end

		# return first sub-entry. useful for array nodes
		def first_entry
			@entries[@entries.keys[0]]
		end

		# is this node an array (or an optional array?)
		def is_array?
			if type.key == :optional
				value.key == :array
			else
				type.key == :array
			end
		end

		# get entries (except when called 'choice') sorted alphabetically
		def sorted_entries
			@sorted_entries ||= @entries.\
				map {|k,v| k.to_s}.\
				reject {|s| s == 'choice'}.sort
		end

		# for a choice node, return the index of the supplied choice key
		def which_choice_is(key)
			sorted_entries.index key.to_s
		end

		# for a choice node, return key at index
		def chosen_option(choice)
			sorted_entries[choice].to_sym
		end

		# is this an option node? (node to be confused with optiopAL)
		def is_option?
			type.key == :option
		end

		# in debug mode?
		def debug?
			@protocol.debug?
		end

		# pack integer
		def pack_int(signed, size, value)
			raise "packed value was nil" unless value
			if debug?
				value.to_s + '!'
			else
				value.pack signed, size
			end
		end

		# unpack integer
		def unpack_int(signed, size, data)
			if debug?
				idx = data.index '!'
				[data[0,idx].to_i,data[idx+1..-1]]
			else
				bytes = size >> 3
				[Fixnum.unpack(signed, data[0,bytes]), data[bytes..-1]]
			end
		end

		# pack boolean
		def pack_bool(value)
			if debug?
				value.to_s + '!'
			else
				"#{value ? "\1" : "\0"}"
			end
		end

		# unpack boolean
		def unpack_bool(data)
			if debug?
				idx = data.index '!'
				[data[0,idx] == 'true', data[idx+1..-1]]
			else
				[(data[0] != 0), data[1..-1]]
			end
		end

		# pack a string
		def pack_string(str)
			pack_int(false, 32, str.size) + str
		end

		# unpack a string
		def unpack_string(data)
			len, data = unpack_int(false, 32, data)
			[data[0,len],data[len..-1]]
		end

		# pack a UID
		def pack_uid(uid)
			if debug?
				raise "not a uid" unless uid.uid?
				pack_string uid
			else
				x = "xxxxxxxx"
				(0..7).each do |i|
					x[i] = eval "0x#{uid[i*2,2]}"
				end
				x
			end
		end

		# unpack a UID
		def unpack_uid(data)
			if debug?
				unpack_string data
			else
				uid = (0..7).map do |i|
					("%02X" % [data[i]])[-2..-1]
				end.join('')
				[uid, data[8..-1]]
			end
		end

		# pack some object value
		def pack_value(value, &block)
			key = is_optional? ? self.value.key : type.key
			case key
			when :u8,:u16,:u32,:u64,:s8,:s16,:s32,:s64
				raise "can't pack nil" unless value
				key = type.key.to_s
				signed = key[0,1] == 's'
				size = key[1..-1].to_i
				pack_int(signed, size, value)
			when :f32,:f64
				raise "can't pack nil" unless value
				pack_float(type.key.to_s[1..-1].to_i, value)
			when :version, :string, :date, :data
				raise "can't pack nil" unless value
				pack_string(value.to_s)
			when :uid
				raise "can't pack nil" unless value
				pack_uid value
			when :sid
				raise "can't pack nil" unless value
				pack_int false, 32, value
			when :array
				raise "can't pack nil" unless value
				value.inject(pack_int(false, 32, value.size)) do |str,v|
					str + v.pack
				end
			when :bool
				raise "can't pack nil (class = #{value.class})" if value.nil?
				pack_bool value
			else
				if block
					yield key, value
				else
					''
				end
			end
		end

		# unpack object value and return remaining data, too
		def unpack_value(data, &block)
			key = is_optional? ? self.value.key : type.key
			case key
			when :u8,:u16,:u32,:u64,:s8,:s16,:s32,:s64
				key = type.key.to_s
				signed = key[0,1] == 's'
				size = key[1..-1].to_i
				unpack_int(signed, size, data)
			when :f32,:f64
				unpack_float(type.key.to_s[1..-1].to_i, data)
			when :version, :string, :date, :data
				unpack_string(data)
			when :uid
				unpack_uid data
			when :sid
				unpack_int false, 32, data
			when :array
				len, data = unpack_int(false, 32, data)
				array = Array.new(len) do |i|
					val = NodeObject.new(@protocol, first_entry)
					data = val.unpack data
					val
				end
				[array, data]
			when :bool
				unpack_bool data
			else
				if block
					yield key, data
				else
					[nil, data]
				end
			end
		end
	end
end
