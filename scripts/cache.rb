container(/cache/, Cache) do

	private

	index		{ @items.keys }
	find		{|uid| Item.new uid }
	add			{|item| @items[item.uid] = item }
	delete	{|item| @items.delete item.uid }

	entity(/UID/, Item) do |uid|
		new		{ edit params }
		edit	{ update params, :data, :owner }
		get do
			@last_use = Time.now
			params[:partial] ? info : body
		end
	end

end

class Cache
	def initialize
		@items = {}
		timer(:interval => config[:interval]) do
			cleanup
		end
	end
	def cleanup
		@items.sort[config[:max_items]..-1].each do |item|
			@items.delete(item.uid).store
		end
	end
end

class Cache::Item
	attr_reader :uid, :last_use
	def initialize(uid)
		@uid = uid
		@last_use = Time.now
		@loaded = false
	end
	def info
		attributes :uid, :owner
	end
	def to_hash
		info.merge :data => @data
	end
	def body
		self.load
		@data
	end
	def <=>(item)
		@last_use <=> item.last_use
	end
	def store
		file(@uid).write(hash)
	end
	def load
		# TODO: load from file(uid).read
	end
end
