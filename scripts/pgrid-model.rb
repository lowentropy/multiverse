class PGrid

	def initialize(uid=nil)
		self.prefix = ''
		self.uid = uid || host[:uid]
		self.links = {@prefix => [host]}
	end

	# specialize domain against another pgrid
	def swap(params)
		grid = self.class.reconstruct params[:pgrid]
		com = common_prefix self.prefix, grid.prefix
		copy_links grid.links, com.size
		r1, r2 = [prefix,grid.prefix].map {|pre| pre[com.size..-1]}
		if r1.size == 0 and r2.size == 0 and com.size < max_prefix_size
			extend_prefix(0, grid)
		elsif	r1.size == 0 and r2.size >  0 and com.size < max_prefix_size
			extend_prefix(1 - grid.prefix[com.size,1].to_i, grid)
		elsif	r1.size > r2.size and r2.size > 0 and params[:depth] < max_depth
			bits = grid.links[prefix[0,com.size+1]][0]
			redirect bits.to_uid.to_host['/grid/swap'], params
		end
	end

	# extend prefix and add ref to other host
	def extend_prefix(bit, grid)
		(links[@prefix] ||= []).delete uid.to_bitstring
		(links[@prefix+(1-bit).to_s] ||= []) << grid.uid.to_bitstring
		@prefix += bit.to_s
	end

	# whether this grid should handle this uid
	def handle?(uid)
		uid.to_bitstring[0,prefix.size] == prefix
	end

end


class Item

	def redirect
		target = @grid.handler_for uid
		$env.reply :code => 302, :body => target[@uri]
	end

	def publish
		@grid.handlers_for(uid).each do |host|
			host[@uri].update to_params
		end
	end

	def internal(action)
		$env.call type, :grid, action
	end

	def del
		internal :delete
	end

	def add
		internal :add
	end

end
