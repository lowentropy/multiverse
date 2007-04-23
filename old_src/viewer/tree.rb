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

require 'includes'
require 'nifty3d/nifty3d'
require 'nifty3d/app'
require 'nifty3d/scene'

include Nifty3D

module MV::Viewer

	class TestScene < Scene

		def init
			@root = Node.group
			@axes = Node.mold :axes
			@sphere1 = Node.new
			@sphere2 = Node.new
			@anchor1 = Node.translate 1, 0, 0
			@pivot11 = Node.group
			@pivot12 = Node.group
			@arm11 = Node.translate 0, 0.5, 0
			@arm12 = Node.translate 0.5, 0, 0
			@anchor2 = Node.translate 0, 0, 1
			@pivot21 = Node.group
			@pivot22 = Node.group
			@arm21 = Node.translate 0, 0.5, 0
			@arm22 = Node.translate 0, 0, 0.5

			@root												\
			<<(@axes										\
				<<(@anchor1								\
					<<(@pivot11							\
						<<(@arm11							\
							<<(@pivot12					\
								<<(@arm12					\
									<<@sphere1)))))	\
				<<(@anchor2								\
					<<(@pivot21							\
						<<(@arm21							\
							<<(@pivot22					\
								<<(@arm22					\
									<<@sphere2))))))	
		end

		def simulate(time, dt)
			@root.rotate_axis 0, 1, 0, dt
			@pivot11.rotate_axis 1, 0, 0, (dt * 3)
			@pivot12.rotate_axis 0, 1, 0, (dt * 7)
			@pivot21.rotate_axis 0, 0, 1, (dt * 7)
			@pivot22.rotate_axis 0, 1, 0, (dt * 3)
		end
	end
end

app = NiftyApp.create
app.scene = MV::Viewer::TestScene.new
app.run
