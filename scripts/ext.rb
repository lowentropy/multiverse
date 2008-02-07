class Fixnum
	def to_hex
		"%x" % [self]
	end
end

# Add basic extensions to String.
class String
	
	# check that we match the uid pattern
	def uid
		raise "invalid uid" unless Regexp::UID =~ self
		self
	end

	# evaluate this string (i.e., treat it as a constant)
	def constantize
		begin
			eval self
		rescue
			nil
		end
	end

	# split a url into parts separated by /
	def url_split
		split('/').reject {|p| p.empty?}
	end

	# find the plural of an english word
	def pluralize
		if self[-1,1] == 'y'
			self[0...-1] + 'ies'
		else
			self + 's'
		end
	end

end


# Adds UID helpers
class Regexp

	# the format of a UID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
	def self.uid_format
		h = '[0-9A-Fa-f]'
		"#{h}{8}-#{h}{4}-#{h}{4}-#{h}{4}-#{h}{12}"
	end

	UID = /#{Regexp.uid_format}/

	# replace instances of {uid} with the uid regex
	def replace_uids
		/#{source.gsub(/\(uid\)/,"(#{Regexp::UID})")}/
	end
end

class Array
	# get self[0..index], and show as path
	def subpath(index=-1)
		'/' + self[0..index].join('/')
	end
end

