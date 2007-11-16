store(/sammich/, Sammich::Store) do
	find {|uid| people[uid] ||= entity.from_path }
	entity(/(uid)/, Sammich::Person) do
		path :uid
		get { complaints }
		store(/complaints/) do
			path :trailing => :type
			index { parent.complaints type }
			add { parent << YAML.load body }
		end
	end
end

fun(:start) { quit }

map_rest
