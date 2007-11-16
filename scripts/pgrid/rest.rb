store(/grid/, PGrid) do
	attributes :prefix
	find		{|uid| entity.from_path }
	add			{|item| item.update }
	entity(/(uid)/, Item) do
		path :uid, :trailing => :target
		get    { internal_redirect }
		update { internal_redirect }
		delete { internal_redirect }
	end
	store(/links/) do
		find  { entity.from_path }
		entity(/([0-9]+)/) do
			path :level
			get { parent.parent.links(level) }
		end
	end
end

fun(:start) { quit }

map_rest
