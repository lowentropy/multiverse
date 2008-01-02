use! 'pgrid'
use! 'rest'

include REST

class Solver
	def initialize
		@problems = {}
	end
	def solve(uid)
		problem = @problems[uid]
		reply :code => 404 and return unless problem
		eval problem
	end
	def add(uid, problem)
		@problems[uid] = problem
	end
end

store(/solver/,Solver) do
	find { entity.from_path }
	entity(/(uid)/) do
		path :uid
		get { parent.solve uid }
		update { parent.add uid, body }
	end
end

map_rest

'/grid'.to_grid.map :solver

fun(:start) { quit }
