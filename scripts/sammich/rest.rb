use! 'rest'
use! 'pgrid'
include REST

store(/sammich/, Sammich::Store) do
	find {|uid| reps[uid] ||= entity.from_path }
	entity(/(uid)/, Sammich::ServerRep) do
		path :uid
		# TODO: cache
		entity(/rep/) do
			get { parent.reputation }
		end
		update { complaints.post }
		store(/complaints/) do
			path :trailing => :type
			index { parent.complaints type }
			add { parent << YAML.load(body) }
		end
	end
end

map_rest

#if use('pgrid')
#	'/grid'.to_grid.map :sammich, /(rep|complaints)/ => '\1/\2'
#end

'/grid'.to_grid.map :sammich, /(rep|complaints)/ => '\1/\2'

fun(:start) { quit }
