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


module MV::Protocol

	# The parser parses protocol definition files and returns
	# an array of toplevel nodes.
	class Parser
		
		def initialize(options={})
			@tab_spaces = options[:tab_spaces] || 2
		end
		
		# read the given file and parse (but not compile) it
		def read_and_parse(filename)
			parse_text File.read(filename)
		end

		# compile the parsed groups into nodes
		def compile(dir, groups)
			groups.map do |group|
				Node.new dir, 'protocol', *group
			end
		end

		# parse some text
		def parse_text(text)
			parse(text.split("\n"))
		end

		# parse a set of lines into group format.
		# spaces become tabs, so it's kinda like loose yaml.
		def parse(lines)
			spaces = ' ' * @tab_spaces
			lines = lines.split("\n") unless lines.respond_to? :[]
			lines.map! {|line| line[0,line.index('#')||line.size]}
			lines.map! do |line|
				line = line.chomp
				a, b = \
					if (idx = line.index '=')
						[line[0..idx], line[idx+1..-1]]
					else
						[line, '']
					end
				a.gsub(spaces, "\t").gsub(/ /,'') + b
			end
			lines.reject! {|line| line.strip.empty?}
			tree = treemap(lines)
			groupmap tree
		end

		# map tabbed lines into a tree structure
		def treemap(lines)
			start_level = lines.empty? ? 0 : count_tabs(lines[0])
			level = start_level
			stack = [[]]

			lines.each do |line|
				tabs = count_tabs line
				if tabs == level
					stack[-1] << line.strip
				elsif tabs == level + 1
					new = [line.strip]
					stack[-1] << new
					stack << new
				elsif tabs < level
					(level-tabs).times {stack.pop}
					stack[-1] << line.strip
				else raise "malformed line (level: #{level} -> #{tabs}): #{line}"
				end
				level = tabs
			end
			(level-start_level).times {stack.pop}
			stack[0]
		end

		# map tree structure of lines into a format that nodes can
		# easily convert from
		def groupmap(tree)
			groups = []
			i = 0
			while i < tree.size
				base = tree[i]
				i += 1
				children = \
					if tree[i].is_a? Array
						i += 1
						groupmap tree[i - 1]
					else
						[]
					end
				groups << [base,children]
			end
			groups
		end

		# returns number of tabs at start of line
		def count_tabs(line)
			i = 0; i += 1 while line[i,1] == "\t"; i
		end
	end

end
