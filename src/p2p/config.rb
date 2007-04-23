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


module MV::P2P

	# host configuration parameters, which are read from the
	# config/host file. it's just a key: value file, where
	# key/key= methods are added to the host config.
	# numeric conversions should be automatic.
	class HostConfig

		def initialize
			base = File.expand_path(File.dirname(__FILE__) + '/../..')
			@settings = {}
			File.open("#{base}/config/host") do |file|
				file.readlines.each do |line|
					line = line.strip
					next if line.empty? || line[0,1] == '#'
					idx = line.index ':'
					key = line[0,idx].strip.to_sym
					val = line[idx+1..-1].strip.split /[ \t]+/
					if val.size == 1
						val = convert val[0]
					else
						val.map! {|v| convert v}
					end
					@settings[key] = val
					add_accessor key
				end
			end
		end

		def convert(val)
			if val.numeric? then val.to_i
			elsif val == "true" then true
			elsif val == "false" then false
			else val
			end
		end

		def add_accessor(key)
			self.class.send(:define_method,key) {@settings[key]}
			self.class.send(:define_method, "#{key}=") {|v| @settings[key] = v}
		end

		def short
			"#{uid} @ #{address}:#{port}"
		end
		
	end
	
end
