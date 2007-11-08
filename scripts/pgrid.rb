req 'pgrid-model.rb'

store(/grid/, PGrid) do

	attributes :uid, :prefix, :links, :size

	# TODO: rest errors should propagate by duplicating
	# the return code and body
	
	# TODO: a cache miss should return a temporary redirect,
	# while a grid miss should return a permanent redirect
	
	index	{ render }
	find	{|uid| Item.new uid, self }
	add		{|item| handle?(item.uid) ? cache.add(item) : item.redirect}

	entity(/(uid)/, Item) do

		path :uid

		new			{ cached.new }
		show		{ @grid.handle?(uid) ? cached.get : redirect }
		update	{ cached.edit; publish unless params[:local] }
		delete	{ owner? ? cached.delete : forbidden }
	end

	behavior(/swap/) { swap params }

end

map_rest
