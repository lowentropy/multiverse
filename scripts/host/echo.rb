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


entity(/host/, LocalHost) do
	
	public

	get do
		info
	end

	behavior(/echo/) do
		{:text => params[:text}}
	end

	private
	
	edit do
		update params
	end

	new do
		@visible = true
	end

	delete do
		@visible = false
	end

end


class LocalHost

	attr_reader :uid, :port

	def initialize
		@params = file(:host).read.as_yaml
		@visible = true
	end

	def update(params={})
		%w(uid port).each do |param|
			eval "@#{param} = @params[:#{@param}] if @params[:#{@param}]"
		end
	end

	def info
		@visible ? @params : forbidden
	end
	
end
