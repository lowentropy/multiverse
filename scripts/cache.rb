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


require 'cache/cache'
require 'cache/handlers'

var :cache

delegate :cache => [:teardown, :heartbeat]

fun :setup do |config|
	$env.cache = k(:DataCache).new config
	$env.setup
end

map :cache do
	map :get do
		resource(/UID/) {|uid| cache.get uid}
	end
	map(/add|update|delete/) do |action|
		action(/UID/) {|uid| cache.send action, uid, msg}
	end
end


klass :CacheItem do

	attr_reader :uid, :owner, :signed, :data, :last_used
	
	def initialize(uid, owner, data, signed)
		@uid, @owner, @data, @signed = uid, owner, data, signed
		modify! and use!
	end
	
	def set_to(owner,data,signed)
		@owner, @data, @signed = owner, data, signed
		modify!
	end
	
	def modify!
		@modified = true
	end
	
	def unmodify!
		@modified = false
	end
	
	def modified?
		@modified
	end
	
	def use!
		@last_used = Time.now.to_i
	end
	
	def used?
		!@last_used.nil?
	end
	
	def <=>(other)
		@last_used <=> other.last_used
	end
end


klass :DataCache do

	use_host_config :max_cache_size

	def initialize(config={})
		@config = config
		@data = {}
		config.each do |uid,arr|
			owner, data, signed = arr
			@data[uid] = $env.k(:CacheItem).new uid, owner, data, signed
			@data[uid].unmodify!
		end
	end
	
	def delta
		config = {}
		@data.values.each do |item|
			next unless item.modified?
			config[item.uid] = [item.owner, item.data, item.signed]
		end
		config
	end

	def put(uid, owner, data, signed)
		if @data[uid]
			return false if @data[uid].signed && (@data[uid].owner != owner)
			@data[uid].set_to owner, data, signed
		else
			@data[uid] = $env.k(:CacheItem).new uid, owner, data, signed
		end
		@config[uid] = [owner, data, signed]
		true
	end

	def get(uid)
		item = @data[uid]
		item ? item.data : nil
	end

	def add
		$env.load_params :uid, :owner, :data, :signed
		if @data[uid]
			$env.reply :uid => uid, :status => :failed, :reason => :duplicate 
		else
			put uid, owner, data, signed
			$env.reply :uid => uid, :status => :succeeded
		end
	end

	def update
		$env.load_params :uid, :owner, :data, :signed
		if put uid, owner, data, signed
			$env.reply :uid => uid, :status => :succeeded
		else
			$env.reply :uid => uid, :status => :failed, :reason => :duplicate
		end
	end

	def delete
		private!
		$env.load_params :uid
		delete uid
	end

	def dump(params)
		@data.keys
	end

	def query(uid)
		item = @data[uid]
		if item
			return item.data, !item.signed.nil?
		else
			return nil, false
		end
	end

	def delete(uid)
		@config.delete uid
		@data.delete uid
	end

	def clear
		@config.clear
		@data.clear
		@cleared = true
	end

	def cleared?
		@cleared
	end

	def clean
		uids = @data.map do |uid,item|
			[item.last_used, uid]
		end.sort.map do |arr|
			arr[1]
		end
		uids[max_cache_size..-1].each do |uid|
			delete uid
		end
	end

	def teardown
		# TODO
	end

	def heartbeat
		# TODO
	end

end
