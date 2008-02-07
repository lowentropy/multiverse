state :default do
start do

MV.req('scripts/ext.rb')
MV.req('scripts/agent.rb')
load_agent('rest').load_client

class << self
	include REST
end

@cache = store(/cache/, Cache) do
	attributes :size
	index		{ @items.keys }
	find		{|uid| @items[uid] }
	add			{|item| @items[item.uid] = item }
	delete	{|item| @items.delete item.uid }
	entity(/(uid)/, Cache::Item) do
		path :uid
		attributes :owner, :uid
		new do
			@data = body
			default_new
		end
		update do
			if @owner && (params[:owner] != @owner)
				reply :code => 401, :body => "wrong owner"
				return
			end
			@data = body if body
			@owner = params[:owner] if params[:owner]
		end
		get do
			reply :code => 404 and return unless @data
			@last_use = Time.now
			@data
		end
	end
end

@cache.serve

end
end
