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

include Nifty3D


module MV::Viewer

	class ViewerApp < GApp

		def init(settings)
			@settings = settings
			@debug = true # FIXME
			setDebugMode @debug
			debugController.setActive @debug
			debugShowRenderingStats = @debug
			debugQuitOnEscape = @debug
		end

		def self.create
			settings = app_settings
			app = ViewerApp.new settings
			app.init settings
			app
		end

		def self.app_settings
			settings = GApp_Settings.new
			settings.data_dir = File.expand_path(
				File.dirname(__FILE__) + '/../../data')
			settings.useNetwork = false
			settings.debugFontName = 'console-small.fnt'
		end

	end

end
