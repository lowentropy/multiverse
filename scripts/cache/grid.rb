fun(:start) { quit }

state :grid do
	fun :find do |uid|
		item = @cache.find uid
		if item
			item.show
		else
			reply :code => 301
		end
	end
	fun :add do |uid|
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
