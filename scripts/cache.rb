# container: regex and model class, match objects
#
container(/cache/, Cache) do

	private

	# index: obtain viewable list of container contents
	# find: obtain entity object from parameters
	# add: add a new item to the container
	# delete: remove the given item
	# entity: define the entity class for the container

	index		{ @items.keys }
	find		{|uid| Item.new uid }
	add			{|item| @items[item.uid] = item }
	delete	{|item| @items.delete item.uid }


	# entity: regex and model class, match objects

	entity(/UID/, Item) do |uid|

		# new: create a new object from params
		# edit: update data with params
		# get: obtain viewable information about entity
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
