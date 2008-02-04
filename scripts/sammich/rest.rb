use 'rest'
use 'pgrid'

store(/sammich/, Sammich::Store) do
	index do
		reps.keys
	end
	find do |uid|
		unless reps[uid]
			reps[uid] = entity.from_path
			reps[uid].reinit
		end
		reps[uid]
	end
	entity(/(uid)/, Sammich::ServerRep) do
		path :uid
		entity(/rep/) do # TODO: cache
			get { parent.reputation }
		end
		update { complaints.post }
		store(/complaints/) do
			path :trailing => :type
			index { parent.complaints type }
			add do
				by, about = params[:by], params[:about]
				parent << Sammich::Complaint.new(by, about)
			end
			# FIXME: shouldn't be required to give an entity
			entity(//) do
				# eh?
			end
		end
	end
end.serve do
	'/grid'.to_grid.map :sammich, /(rep|complaints)/ => '\1/\2'
end
