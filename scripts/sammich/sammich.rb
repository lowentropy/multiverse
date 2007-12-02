class Fixnum
	def sign
		self < 0 ? -1 : (self > 0 ? 1 : 0)
	end
end

class Array
	def sum
		inject(0) {|s,i| s + i}
	end
end

class Object
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
		def by?(uid)
			@by == uid
		end
		def about?(uid)
			@about == uid
		end
		def post_to(somewhere)
			y = self.to_yaml
			somewhere[by].complaints.post y
			somewhere[about].complaints.post y
		end
	end

	class Reputation
		def initialize(uid)
			@uid = uid
			@rep = "/grid/#{@uid}/rep".to_entity
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
		def update
			@complaints = @rep.get
			@by, @about = [], []
			@complaints.each do |c|
				(c.by?(@uid) ? @by : @about) << c
			end
		end
		def <<(complaint)
			@rep.put complaint.to_yaml
			@complaints << complaint if @complaints
		end
		private
		def decide(r, f)
			r * f <= @ra * @fa * (0.5 + 4.0 / ((@ra * @fa) ** 0.5)) ** 2.0
		end
		public
		def reputation!(level=nil)
			@complaints = nil
			reputation level
		end
		def reputation(level=nil)
			return 0 if (level ||= 1) <= 0
			w = {}
			complaints.each do |c|
				a = (c.by == uid) ? c.about : c.by
				w[a] ||= [0,0,0]
				w[a][c.by == uid ? 1 : 0] += 1
				w[a][2] += 1
			end
			return 0 if w.size == 0
			s = w.map {|i| i[2]}.sum.to_f
			w.each do |a,i|
				i[0] *= (1.0 - ((s - i[2]) / s) ** s)
				i[1] *= (1.0 - ((s - i[2]) / s) ** s)
			end
			if w.size == 1
				return 0 if (a = w.keys[0]).rep(level-1) < 1
				return decide(w[a][0], w[a][1])
			end
			s = w.values.map {|c| decide(c[0], c[1])}.sum
			return s.sign if (s / 2) != 0
			w.reject! {|a,c| a.rep(level-1) < 1}
			w.values.map {|c| decide(c[0], c[1])}.sum.sign
		end
		alias :rep :reputation
	end

	class ServerRep < Reputation
		def initialize
			@about = []
			@by = []
		end
		def complaints(scope=:all)
			case scope.to_s
			when 'all' then @about + @by
			when 'about' then @about
			when 'by' then @by
			else reply :code => 500, :body => "i don't know what that is"
			end
		end
		def <<(complaint)
			if complaint.by? self
				@by << complaint
			elsif complaint.about? self
				@about << complaint
			else
				reply :code => 500, :body => "keep me out of it"
			end
		end
	end

end
