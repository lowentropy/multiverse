module Sammich
	
	class Store
		attr_reader :people
		def initialize
			@people = {}
		end
	end

	class Complaint
		def initialize(by, about)
			@by, @about = by, about
		end
	end

	class Person
		def initialize
			@about = []
			@by = []
		end
		def complaints(scope=:all)
			case scope.to_s
			when 'all' then @about + @by
			when 'about' then @about
			when 'by' then @by
			else reply :code => 500, :body => 'i don\'t know what that is'
			end
		end
		def <<(complaint)
			if complaint.by? self
				@by << complaint
			elsif complaint.about? self
				@about << complaint
			else
				reply :code => 500, :body => 'keep me out of it'
			end
		end
	end

end
