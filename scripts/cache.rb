req 'scripts/cache-model.rb'

fun(:start) { quit }

store(/cache/, Cache) do
	
	attributes :size

	index		{ @items.keys }
	find		{|uid| @items[uid] }
	add			{|item| @items[item.uid] = item }
	delete	{|item| @items.delete item.uid }

	entity(/(uid)/, Cache::Item) do

		path :uid
		attributes :data, :owner

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

map_rest
