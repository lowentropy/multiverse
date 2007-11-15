req 'pgrid-model.rb'

store(/grid/, PGrid) do

	attributes :uid, :prefix, :links, :size

	index		{ render }
	find		{|uid,type| Item.new uid, type }
	add			{|item| handle?(item.uid) ? item.add : item.redirect }
	delete	{|item| handle?(item.uid) ? item.del : item.redirect }

	# TODO: routing should allow / in regex by including a number
	# of path parts equal to # of /'s + 1
	entity(/(uid)\/(.+)/, Item) do

		path :uid, :type

		show		{ @parent.handle?(uid) ? cached.find : redirect }
		update	{ add; publish unless params[:local] }
		delete	{ owner? ? del : forbidden }
	end

	behavior(/swap/) { swap params }

end

map_rest
