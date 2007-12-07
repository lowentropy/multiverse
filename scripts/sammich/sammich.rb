class ::Fixnum
	def sign
		self < 0 ? -1 : (self > 0 ? 1 : 0)
	end
end

class ::Array
	def sum
		self.inject(0) {|s,i| s + i}
	end
end

class ::Object
	def rep
		raise "must have a uid" unless respond_to? :uid
		Sammich::Reputation.new uid
	end
end


module Sammich
	
	class Store
		attr_reader :reps
		def initialize
			@reps = {}
		end
	end

	class Complaint
		attr_reader :by, :about
		def initialize(by, about)
			@by, @about = by, about
		end
		def by?(obj)
			@by == obj.uid
		end
		def about?(obj)
			@about == obj.uid
		end
		def post_to(somewhere)
			somewhere[by].complaints.post '', hash
			somewhere[about].complaints.post '', hash
		end
		def hash
			{:by => by, :about => about}
		end
	end

	class Reputation
		attr_reader :uid
		def initialize(uid)
			@uid = uid
			@rep = "/grid/#{@uid}/complaints".to_store
		end
		def trust?
			reputation > 0
		end
		def complaints
			update unless @complaints
			@complaints
		end
		def complaints!
			@complaints = nil
			complaints
		end
		def by
			@complaints.reject {|c| c.about?(uid)}
		end
		def about
			@complaints.reject {|c| c.by?(uid)}
		end
		def update
			@complaints = @rep.get.map {|c| Complaint.new(c[:by],c[:about])}
			@by, @about = [], []
			@complaints.each do |c|
				if c.by? @uid
					@by << c
				else
					@about << c
				end
			end
		end
		def <<(complaint)
			@rep.post '', :by => complaint.by, :about => complaint.about
			@complaints << complaint if @complaints
		end
		private
		def decide(r, f, ra, fa)
			a = r * f
			b = ra * fa * (0.5 + 4.0 / ((ra * fa) ** 0.5)) ** 2.0
			(a <= b) ? 1 : -1
		end
		public
		def reputation!(level=nil)
			@complaints = nil
			reputation level
		end
		def reputation(level=nil,ra=0,fa=0)
			return 0 if (level ||= 1) <= 0
			w = {}
			complaints.each do |c|
				a = (c.by == uid) ? c.about : c.by
				w[a] ||= [0,0,0]
				w[a][c.by == uid ? 1 : 0] += 1
				w[a][2] += 1
			end
			return 0 if w.size == 0
			s = w.values.map {|i| i[2]}.sum.to_f
			w.each do |a,i|
				i[0] *= (1.0 - ((s - i[2]) / s) ** s)
				i[1] *= (1.0 - ((s - i[2]) / s) ** s)
			end
			if w.size == 1
				return 0 if (a = w.keys[0]).rep.reputation(level-1,ra,fa) < 1
				return decide(w[a][0], w[a][1], ra, fa)
			end
			r = w.values.map {|c| c[0]}.sum
			f = w.values.map {|c| c[1]}.sum
			s = decide(r, f, ra, fa)
			# FIXME: allow variable margin
			return s.sign #if (s / 2) != 0
			w.reject! {|a,c| a.rep.reputation(level-1,ra,fa) < 1}
			w.values.map {|c| decide(c[0], c[1], ra, fa)}.sum.sign
		end
		alias :rep :reputation
	end

	class ServerRep < Reputation
		def initialize
			@about = []
			@by = []
		end
		# XXX: HACK
		def reinit
			@about, @by = [], []
		end
		def complaints(scope='/all')
			scope = scope[1..-1]
			scope = :all unless scope and scope.size > 0
			case scope.to_s
			when 'all' then @about + @by
			when 'about' then @about
			when 'by' then @by
			else
				reply :code => 500, :body => "i don't know what '#{scope}' is"
				return
			end.map {|c| c.hash}
		end
		def <<(complaint)
			if complaint.by? self
				@by << complaint
			elsif complaint.about? self
				@about << complaint
			else
				reply :code => 500, :body => "#{complaint.inspect} not relevant to #{uid} with params #{params.inspect} and body #{body}"
			end
		end
	end

end
