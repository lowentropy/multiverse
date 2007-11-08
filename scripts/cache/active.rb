map(/grid/) do
	fun :find do |uid|
		begin
			reply :body => @cache[uid].get
		rescue RestError => e
			e.code = 301 if e.code == 404
			e.reply
		end
	end
	fun :add do |uid,body,params|
		@cache[uid].put body, params
	end
	fun :delete do |uid|
		@cache[uid].delete
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
