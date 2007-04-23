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
require 'protocol/node'
require 'protocol/parser'


module MV::Protocol

	# A protocol is basically a directory of types. You can also register
	# nodes of type other than 'type' manually (usually, this means
	# nodes of type :message)
	class Protocol

		attr_reader :types, :nodes, :registry_types
		
		def initialize(debug)
			@debug = debug
			@types = {}
			@registry = {}
			@registry_types = []
			@nodes = []
			add_default_types
		end

		def debug?
			@debug
		end
		
		# read the host's core protocol file and register it
		# (by storing all nodes of type :message)
		def register_protocol(file=nil)
			base = File.expand_path(File.dirname(__FILE__) + '/../..')
			file ||= "#{base}/config/protocol"
			register_file file, :message
		end

		# parse a file into a protocol format and register
		# any of the given types from the file into the directory
		def register_file(filename, *types)
			register_text File.read(filename), *types
		end

		def register_text(text, *types)
			parser = Parser.new
			groups = parser.parse_text text
			nodes = parser.compile self, groups
			nodes.each do |node|
				@nodes << node
				types.each do |type|
					@registry_types << type unless @registry_types.include? type
					node.register_all type
				end
			end
		end

		def register_all(type)
			@nodes.each do |node|
				node.register_all type
			end
		end

		# register the given node of the given type and key
		def register(type, key, node)
			@registry[type] ||= {}
			@registry[type][key] = node
		end

		# add the type-type
		def add_default_types
			add_default_type :type
		end

		# add a builtin type
		def add_default_type(key)
			types[key.to_sym] = Node.type self, key
		end

		# find a node given its type and key. if failok is true,
		# will return nil on failure, else throws and error.
		def find_by_type(type, key, failok=false)
			nodes = @registry[type]
			if nodes
				node = nodes[key]
				return node if node
			end
			unless failok
				raise "can't find node #{key} of type #{type}"
			end
			nil
		end

		# find a node of type 'type' and given key
		def find_type(key, failok=false)
			type = types[key.to_sym]
			raise "can't find type '#{key}'" unless type or failok
			type
		end

		# update a type with a later statement by appending the new
		# type's entries to it. if we didn't know about this type,
		# add it fresh.
		def update_type(key, node)
			raise "updating #{key} with nil type" unless node
			raise "update #{key} is not a type" unless node.is_type?
			type = find_type key, true
			if type
				type.update_with node
			else
				types[key.to_sym] = node
			end
		end

		def add_node(node)
			@nodes << node
		end

		def clone
			protocol = Protocol.new(@debug)
			protocol.append! self
			protocol
		end

		def append(protocol)
			clone.append! protocol
		end

		def append!(protocol)
			protocol.types.each do |key,type|
				update_type key, type
			end
			protocol.nodes.each do |node|
				add_node node
			end
			protocol.registry_types.each do |type|
				register_all type
			end
			self
		end
	end
end
