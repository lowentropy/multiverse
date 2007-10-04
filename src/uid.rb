class UID

	# generate a random 128-bit number
	# as per rfc 4122 (uuid)
	def self.random
		[8,4,4,4,12].map {|n| rand_hex(n)}.join '-'
	end

	private
	def self.rand_hex(n)
		"%0#{n}X" % [rand(2 ** (n * 4))]
	end

end

