# TODO: add 'use'
use 'rest', 'pgrid'

store(/sammich/, Sammich::Store) do
	find {|uid| reps[uid] ||= entity.from_path }
	entity(/(uid)/, Sammich::Reputation) do
		path :uid
		cache { entity(/rep/) do
			get { parent.reputation }
		end }
		update { complaints.post }
		store(/complaints/) do
			path :trailing => :type
			index { parent.complaints type }
			add { parent << YAML.load body }
		end
	end
end

fun(:start) do
	'/grid'.to_grid.map(/(rep|complaints)/, :sammich, '\1/\2')
	map_rest
	quit
end
