collection(/grid/, PGrid) do

	attributes :uid, :prefix, :links, :size

	public
	index	{ render }
	find	{|uid| Item.new uid, self }
	add		{|item| handle?(item.uid) ? cache.add(item) : item.redirect}

	entity(/({uid})/, Item) do

		public
		path :uid

		create	{ cached.new }
		show		{ @grid.handle?(uid) ? cached.get : redirect }
		update	{ cached.edit; publish unless params[:local] }
		delete	{ owner? ? cached.delete : forbidden }
	end

	private
	behavior(/swap/) { swap params }

end


class PGrid

	def initialize(uid=nil)
		self.prefix = ''
		self.uid = uid || host[:uid]
		self.links = {@prefix => [host]}
	end

	def cache
		'/cache/'.to_collection
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
	def handles?(uid)
		uid.to_bitstring[0,prefix.size] == prefix
	end

end



class Item

	attributes :data, :signature

	def initialize(uid, grid)
		@uid = uid
		@grid = grid
	end

	def cached
		@cached ||= "/cache/#{uid}".to_entity
	end

	def redirect
		target = @grid.handler_for uid
		redirect target[uri], :handlers => hosts
	end

	def publish
		@grid.handlers_for(uid).each do |host|
			host[uri].update to_params
		end
	end

end
