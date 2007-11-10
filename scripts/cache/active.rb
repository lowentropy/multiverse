map(:grid) do
	fun :find do |uid|
		if (item = @cache.find uid)
			reply :body => item.render
		else
			reply :code => 301
		end
	end
	fun :add do |uid|
		# NOTE: body and params should get cloned from pgrid
		item = @cache.entity.from_path uid
		item.new
		@cache.add item
	end
	fun :delete do |uid|
		item = @cache.find uid
		if item
			@cache.delete item
		else
			reply :code => 404
		end
	end
end

@cache = store(/cache/, Cache) do
	attributes :size
	index		{ @items.keys }
	find		{|uid| @items[uid] }
	add			{|item| @items[item.uid] = item }
	delete	{|item| @items.delete item.uid }
	entity(/(uid)/, Cache::Item) do
		path :uid
		attributes :data, :owner, :uid
		new do
			default_new
		end
		update do
			if @owner && (params[:owner] != @owner)
				reply :code => 401, :body => "wrong owner"
				return
			end
			@data = params[:data] if params[:data]
			@owner = params[:owner] if params[:owner]
		end
		get do
			reply :code => 404 and return unless @data
			@last_use = Time.now
			@data
		end
	end
end
