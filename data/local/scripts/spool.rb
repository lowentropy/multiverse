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

var :spool
delegate :spool => [:heartbeat, :teardown]

fun :setup do
	$env.spool = k(:Spool).new
	$env.spool.setup
end

map 'spool' do
	public
		delegate :spool => [:new, :spool, :unspool, :resend]
	private
		delegate :spool => [:send_to]
end

klass :Spool do

	def initialize
		@chunks = {}
		@size = {}
		@data = {}
		@host = {}
		@outbox = {}
	end

	def stream(uid, size, host)
		@chunks[uid] = {}
		@size[uid] = [size,0]
		@data[uid] = nil
		@host[uid] = host
	end

	def spool(uid, chunk, seq)
		@size[uid] += 1 if @chunks[seq].nil?
		@chunks[uid][seq] = chunk
	end

	def unspool(uid)
		until ready? uid
			if missing? uid
				return nil unless get_missing uid
			end
		end
		glue uid
	end

	def clear
		@chunks.clear
		@size.clear
		@data.clear
		@outbox.clear
	end

	def cache_outgoing(uid, host, chunks)
		@outbox[uid] = [host, chunks, Time.now.to_s]
	end

	def outgoing_chunk(uid, seq)
		return nil unless @outbox[uid]
		@outbox[uid][1][seq]
	end

	def clean
		uids = @outbox.map do |uid,arr|
			[arr[2], uid]
		end.sort.map do |arr|
			arr[1]
		end
		uids[host.config.max_outgoing_spool_length..-1].each do |uid|
			@outbox.delete uid
		end
	end

	def missing?(uid)
		return false unless @outbox[uid]
		return false if @chunks[uid][@size[uid]-1].nil?
		@chunks[uid].each do |chunk|
			return true unless chunk
		end
		false
	end

	def get_missing(uid)
		chunks = @chunks[uid]
		return unless chunks
		0.upto(@size[uid]-1) do |seq|
			next if chunks[seq]
			chunk = get_missing_chunk uid, seq
			return false unless chunk
			chunks[seq] = chunk
		end
		true
	end

	def send_to(uid, host, data)
		size = host.config.chunk_size
		chunks, remaining = [], data
		until remaining.empty?
			chunks, remaining = remaining[0,size], remaining[size..-1]
		end
		host.put '/spool/new', :uid => uid, :num_chunks => chunks.size
		chunks.each_with_index do |chunk,i|
			host.put '/spool/spool', :uid => uid, :sequence_id => i, :data => chunk
		end
		cache_outgoing uid, host, chunks
	end

	def resend(uid, sequence_id)
		chunk = outgoing_chunk uid, sequence_id 
		status = chunk ? :sent : :not_sent
		reply :uid => uid, :sequence_id => seq, :data => chunk, :status => :sent
	end

private

	def ready?(uid)
		@size[uid][0] == @size[uid][1]
	end

	def glue(uid)
		@data[uid] ||= @chunks[uid].join('')
	end

	def get_missing_chunk(uid, seq)
		while true
			reply = script.send? :sync, @host[uid], :resend_chunk,
				:uid => uid, :sequence_id => seq
			break if reply and reply.key == :resend_chunk_ack
		end
		if reply.status.key == :sent
			reply.data
		else
			nil
		end
	end
end
