req 'pgrid-model.rb'

store(/grid/, PGrid) do
	attributes :uid, :prefix, :size
	find		{|uid| entity.from_path }
	add			{|item| item.update }
	entity(/(uid)/, Item) do
		path :uid
		show { internal_redirect }
		update { internal_redirect }
		delete { internal_redirect }
	end
end

map_rest
