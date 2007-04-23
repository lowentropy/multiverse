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
require 'util/uid'
require 'script/environment'


module MV::Script

	class Runner

		def initialize(host)
			@host = host
		end

		def self.run(host, script, start_state=nil)
			Runner.new(host).run script, start_state
		end

		def run(script, start_state=nil)
			begin
				env = Environment.new @host
				env.add_script script
				env.start_env start_state
			ensure
				env.join
			end
		end
	end

end
