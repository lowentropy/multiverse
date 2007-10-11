module PartialDelegator

	def delegate(to, *functions)
		to = "to." unless to.is_a? String
		functions.each do |fun|
			eval <<-END
				puts "defining #{fun} on #{self}"
				def #{fun}(*args, &block)
					$env.dbg "calling delegate #{fun} in #{to}"
					#{to}#{fun} *args, &block
				end
			END
		end
	end

end
