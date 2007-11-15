# The PGrid Root Collection
class PGrid

	# start by accepting all uids
	def initialize
		@prefix = ''
		@links = {}
	end

	def bits(uid)
		h = '[0-9a-zA-Z]'
		p = /(#{h}{8})-(#{h}{4})-(#{h}{4})-(#{h}{4})-(#{h}{12})/
		p.match(uid)[1..-1].map do |hex|
			"%0#{hex.size*4}b" % [eval("0x#{hex}")]
		end.join ''
	end

	# returns all links up to and including length 'level'
	def links(level)
		@links.reject {|pre,host| pre.size > level}
	end

	# specialize domain against another pgrid
	def swap(grid, prefix)
		com = common_prefix @prefix, prefix
		copy_links grid.links, com.size
		links = grid.links.to_store[com.size].get
		r1, r2 = [@prefix, prefix].map {|pre| pre[com.size..-1]}
		if r1.size == 0 and r2.size == 0 and com.size < max_prefix_size
			extend_prefix(0, grid)
		elsif	r1.size == 0 and r2.size >  0 and com.size < max_prefix_size
			extend_prefix(1 - grid.prefix[com.size,1].to_i, grid)
		elsif	r1.size > r2.size and r2.size > 0 \
			and params[:depth] < max_depth
			bits = grid.links[prefix[0,com.size+1]][0]
			redirect bits.to_uid.to_host['/grid/swap'], params
		end
	end

	# extend prefix and add ref to other host
	def extend_prefix(bit, grid, prefix)
		(links[@prefix] ||= []).delete bits(uid)
		(links[@prefix+(1-bit).to_s] ||= []) << grid
		@prefix += bit.to_s
	end

	# whether this grid should handle this uid
	def handle?(uid)
		bits(uid)[0,size] == prefix
	end

	# size of our prefix
	def size
		prefix.size
	end

	# get all handlers for a uid
	def handlers_for(uid)
		bits = bits(uid)
		@links.reject {|pre,host| bits[0,pre.size] != pre}.values.uniq
	end

	# get a random handler for a uid
	def handler_for(uid)
		handlers = handlers_for uid
		handlers[rand(handlers.size)]
	end

end

# A single item in the grid. Note that these objects are
# created on the fly and contain no real data.
class Item

	# link to parent grid
	def grid
		@parent
	end

	# make an internal call to the target of the grid request
	def internal_redirect
		redirect and return unless grid.handle? uid
		uri = '/' + (@uri[uid.size+1..-1] || 'cache') + "/#{uid}"
		code, body = $env.send method, uri, body, params
		redirect(301, body) if code == 404
		reply :code => code, :body => body unless $env.replied?
	end

	# redirect to another host
	def redirect(code=302, body=nil)
		target = grid.handler_for uid
		if target
			$env.reply :code => code, :body => target.to_host[uri]
		else
			$env.reply :code => 404, :body => body
		end
	end

	# publish to other pgrids given the same body and params
	# that were used for this call. don't block.
	def publish
		Thread.new(self) {|item| item.publish!}
	end

	# publish to other pgrids given the same body and params
	# that were used for this call. blocks.
	def publish!
		@grid.handlers_for(uid).each do |host|
			host.to_host[@uri].to_entity.put body, params
		end
	end

end
