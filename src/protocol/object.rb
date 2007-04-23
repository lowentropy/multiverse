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

	# A node object is an instantiation of a node (which should really
	# be called a template FIXME). It has specific values, and performs
	# some of the meta-behavior of the protocol format (like optionals
	# and arrays). It also knows how to serialize and deserialize itself.
	class NodeObject

		attr_accessor :node, :value, :protocol

		# create self-attributes from the node (template) definition.
		# the given block is called with self as its argument, if present.
		def initialize(protocol, node, &block)
			self.protocol = protocol
			self.node = node
			self.node.each do |key,node|
				create_method(key) {eval("@#{key}").simple_value}
				create_method("#{key}=") {|v| eval("@#{key}").set_to v; v}
				self.instance_variable_set "@#{key}", \
					NodeObject.new(protocol, node, &block)
			end
			self.value = self.node.value
			unassign!
			yield self if block
		end

		def key
			node.key
		end

		# clone the object
		def clone
			obj = NodeObject.new(protocol, node)
			obj.set_to value
			node.each do |k,v|
				val = self.instance_variable_get "@#{k}"
				obj.instance_variable_set "@#{k}", val.clone
			end
			obj.assign! if @assigned
			obj
		end

		def simple(value)
			if value.kind_of? NodeObject
				value.simple_value
			elsif value.is_a? Array
				value.map {|v| simple(v)}
			else
				value
			end
		end

		# return the value if it's a simple type, or ourself if
		# it isn't
		def simple_value
			if node.type.simple?
				simple(value)
			elsif node.type.key == :array
				value.map {|v| simple(value)}
			elsif node.type.key == :optional
				@assigned ? simple(value) : nil
			elsif node.type.key == :option
				simple(chosen_option)
			else
				self
			end
		end

		# helper to create instance methods
		def create_method(name, &block)
			self.class.send :define_method, name, &block
		end

		# returns true of this is a type object (which should never
		# actually happen... FIXME)
		def is_type?
			raise "foo"
			node.is_type?
		end

		# return the base type (as above... FIXME)
		def base_type
			raise "not a type" unless is_type?
			node.value
		end

		# using a hash of value | {key => value | {key => ...}}, instantiate
		# the values of this object and its sub-objects
		def set_attributes(content)
			content.each do |key,value|
				raise "invalid attribute #{key} for #{node.key}" unless respond_to? key
				var = instance_variable_get "@#{key}"
				raise "attribute #{key} is not set on #{node.key}" unless var
				var.set_to value
			end
		end

		# set the value of this object. if the argument is a hash,
		# behaves like set_attributes. otherwise, attempts to
		# set the value as interpreted by the node's type
		# (or the node's value-type, in case of optionals)
		def set_to(value)
			if value.is_a? Hash
				if node.is_option?
					value[:choice] = node.which_choice_is value.keys[0]
				end
				set_attributes value
			elsif node.is_option?
				self.set_to({value => {}})
			else
				type =
					if node.is_optional?
						assign! if value
						node.value
					else
						node.type
					end
				self.value = type.interpret value, node.first_entry
			end
			self
		end

		# mark that this optional value was assigned
		def assign!
			@assigned = true
		end

		# mark that this optional value was unassigned
		def unassign!
			@assigned = false
		end

		# yield each sub-object (NOT it's simple value)
		def each(&block)
			return if node.is_array?
			node.each do |key,node|
				yield key, instance_variable_get("@#{key}")
			end
		end

		# recursive print function (with some extra functionality
		# for arrays)
		def print(pre='')
			if node.is_array?
				asgn = "(assigned = #{@assigned})" if node.is_optional?
				puts "#{pre}#{node.key} : #{node.type.key} #{asgn} = array"
				value.each do |element|
					element.print(pre+'  ')
				end
			elsif node.is_option?
				puts "#{pre}#{node.key} : #{node.type.key} ="
				key = node.chosen_option choice
				instance_variable_get("@#{key}").print(pre+'  ')
			elsif NodeObject === value
				puts "#{pre}#{node.key} : #{node.type.key} ="
				value.print(pre+'  ')
			else
				asgn = "(assigned = #{@assigned})" if node.is_optional?
				puts "#{pre}#{node.key} : #{node.type.key} #{asgn}= #{value}"
				each {|key,obj| obj.print(pre+'  ')}
			end
		end
	end

	# marshal object into stream
	def marshal
		"#{node.key.to_s}!#{pack}"
	end

	# unmarshal into new object
	def self.unmarshal(protocol, data)
		idx = data.index '!'
		key, packed = data[0,idx], data[idx+1..-1]
		NodeObject.new(protocol, protocol.find(key.to_sym)).unpack(packed)
	end

	# pack this object into a string
	def pack
		begin
			if node.is_option?
				node.pack_value(value) + \
				node.pack_int(false, 8, choice) + chosen_option.pack
			elsif node.is_optional?
				node.pack_bool(@assigned) + \
					if @assigned
						if node.is_array?
							node.pack_value(value)
						else
							node.pack_value(value) + default_pack
						end
					else
						''
					end
			elsif node.is_array?
				node.pack_value value
			else
				node.pack_value(value) {|k,v| pack_special k, v} + default_pack
			end
		rescue Exception => e
			puts "error packing #{node.key}'s value"
			raise e
		end
	end

	# default pack is to pack sub-objects in order
	def default_pack
		node.sorted_entries.inject('') do |str,key|
			str + instance_variable_get("@#{key}").pack
		end
	end

	# unpack a string into this blank object
	def unpack(data)
		if node.is_option?
			self.value, data = node.unpack_value data
			self.choice, data = node.unpack_int(false, 8, data)
			data = chosen_option.unpack data
		elsif node.is_optional?
			@assigned, data = node.unpack_bool(data)
			if @assigned
				if node.is_array?
					self.value, data = node.unpack_value data
				else
					self.value, data = node.unpack_value data
					data = default_unpack data
				end
			else
			end
		elsif node.is_array?
			self.value, data = node.unpack_value data
		else
			self.value, data = node.unpack_value(data) {|k,d| unpack_special k, d}
			data = default_unpack data
		end
		data
	end

	# override this for custom behavior in packing values
	def pack_special(key, value)
		''
	end

	# override this for custom behavior in unpacking values
	def unpack_special(key, data)
		[nil, data]
	end

	# default unpack is to unpack sub-entries in sorted order
	def default_unpack(data)
		node.sorted_entries.each do |key|
			data = instance_variable_get("@#{key}").unpack data
		end
		data
	end

	# return the value (or node) that is this option's chosen value
	def chosen_option
		raise "not an option object" unless node.is_option?
		send node.chosen_option(choice)
	end

	# inspect is just to_s
	def inspect
		to_s
	end

end
