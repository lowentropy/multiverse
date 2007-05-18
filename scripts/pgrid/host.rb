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


# PGridHost maintains references to other hosts
# and knows its own prefix.
klass :PGridHost do

	attr_reader :prefix, :pointers, :host_uid, :seeds, :host

	# initial prefix is ALL resources
	def initialize(host, prefix=nil, pointers=nil, host_uid=nil)
		@host = host
		@host_uid = host_uid || host.uid
		@prefix = prefix || ''
		@pointers = pointers || {}
		@seeds = []
	end

	# load pgrid host from a config file
	def self.load(host, config)
		return new(host) if config.empty?
		prefix = config[:prefix]
		pointers = eval config[:pointers]
		host_uid = config[:host]
		new(host, prefix, pointers, host_uid)
	end

	# store pgrid host to config file format
	def config
		{	:host => @host_uid,
			:prefix => @prefix,
			:pointers => @pointers.inspect}
	end

	def seed_uids
		seeds.map {|info| info.uid}
	end

	def common(a, b)
		i = 0
		s = ''
		n = min a.size, b.size
		while i < n
			return s unless a[i] == b[i]
			s << a[i,1]
		end
		s
	end

	def min(a, b)
		a < b ? a : b
	end

	def copy_pointers(pointers, level)
		# TODO
	end

	def max_path_length
		# FIXME: get from configuration
		64
	end

	# perform pgrid exchange between hosts
	def exchange(host, grid, depth, initiator)

		# copy pointers at matching level
		pre = common prefix, grid.prefix
		lc = pre.size
		copy_pointers grid.pointers, lc

		# get remaining prefixes
		r1, r2 = prefix[lc..-1], grid.prefix[lc..-1]
		l1, l2 = r1.size, r2.size

		# same prefix: extend on both sides
		if l1 == 0 and l2 == 0 and lc < max_path_length
			mybit = initiator ? 0 : 1
			extend_prefix mybit, grid

		# this prefix less specific: specialize against other
		elsif l1 == 0 and l2 > 0 and lc < max_path_length
			mybit = 1 - grid.prefix[lc,1].to_i
			extend_prefix mybit, grid

		# refer to other's pointer, which is closer to us
		elsif l1 > l2 and l2 > 0 and depth < max_depth
			grid.pointers[prefix[0,lc+1]].each do |bits|
				uid = bits.to_uid
				bits.to_uid.to_host.put '/pgrid/exchange',
					:config => config.inspect,
					:depth => depth + 1,
					:respond => true
			end
		end
	end

	# TODO: get from config
	def require_cache_sigs?
		false
	end

	# TODO: get from config
	def should_chunk?(size)
		false
	end

	# find out if we have a signed data item
	def have_signed?(uid)
		ok, signed = signal? :query_cache, uid
		ok ? signed : false
	end

	# the other hosts which can handle this uid
	# (ordered by specificity right now...)
	def handlers(uid)
		result = []
		uid = uid.to_bitstring
		prefix.size.downto(0) do |len|
			pref = uid[0,len]
			pointers[pref] ||= []
			pointers[pref].each do |pointer|
				result << pointer.to_uid
			end
		end
		result
	end
end


