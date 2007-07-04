# REST interface

collection(/grid/, PGrid) do
# sends :collection, regex and unique service key to server

	public
	# local dispatcher will not throw priv errors

	index	{ render }
	# this action is a block that is called instance_eval on a singleton
	# instance of the class PGrid; a session key is provided which allows
	# local access to things like the current match values
	#
	# render will take the REST return type and try to convert the
	# instance into that and then render and return it

	find	{|uid| Item.new uid, self }
	# an entity def's path values are used to get the match values as in
	# any collection action, but in this case called with the *entity's*
	# match values as parameters
	#
	# constants should be looked up inside the anonymous module

	add		{|item| handle?(item.uid) ? cache.add(item) : item.redirect}
	# *after* the item has been constructed, this is called

	entity(/(UID)/, Item) do
	# collections can have many entity classes, their regexes will try
	# to match in order

		path :uid
		# sets @path on the def., which will be used when matching the url

		create	{ cached.new }
		# called in a sandbox-type environment where the path parts
		# are accessor for the url match

		show		{ @grid.handle?(uid) ? cached.get : redirect }
		# this is like the show action

		update	{ cached.edit; publish unless params[:local] }
		# this is the update action

		delete	{ owner? ? cached.delete : forbidden }
		# this is called before the collection's version
	end

	behavior(/swap/) { swap params }
	# this is called on the collection instance

end


# COLLECTION class
class PGrid

	attributes :uid, :prefix, :links
	# render action will try to use these to serialize the object
	#
	# also should add attr_accessor's.
	#
	# also creates a reconstruct method that
	# calls an empty initializer and sets the params
	#
	# should add a to_params method too

	def initialize(uid=nil)
		self.prefix = ''
		self.uid = uid || host[:uid]
		self.links = {@prefix => [host]}
	end

	def cache
		'/cache/'.to_collection
		# this produces a collection-api wrapper to a partial reference (def. lh)
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


# ENTITY class

class Item

	collection :PGrid
	# this should not have to be called...
	# it will be added when coll.entity is claled

	# wait... where is the data?

	def initialize(uid, grid)
		@uid = uid
		@grid = grid
	end

	def url
		"/grid/#{uid}"
	end

	def cached
		@cached ||= "/cache/#{uid}".to_entity
	end

	def redirect
		target = @grid.handler_for uid
		redirect target[url], :handlers => hosts
		# what does this do?
	end

	def publish
		@grid.handlers_for(uid).each do |host|
			host[url].update to_params
		end
	end

end
