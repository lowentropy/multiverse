$: << File.dirname(__FILE__)


#
# At 1 new UID per second, there is an 84% chance that
# no UIDs will collide for at least 100 billion years.
#


class UID

	# generate a random 64-bit number, rendered
	# as a 16-character hex string
	def self.random
		'%016X' % [rand(2 ** 64)]
	end

end

