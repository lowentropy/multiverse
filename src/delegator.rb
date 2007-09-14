module PartialDelegator

	def delegate(to, *functions)
		to = "to." unless to.is_a? String
		functions.each do |fun|
			eval <<-END
				def #{fun}(*args, &block)
					#{to}#{fun} *args, &block
				end
			END
		end
	end

end
