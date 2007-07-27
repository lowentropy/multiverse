class String
	def constantize
		begin
			eval self
		rescue
			nil
		end
	end
end

class Regex
	def replace_uids
		/#{source.gsub(/\{uid\}/,'[0-9a-fA-F]{16}')}/
	end
end

class Hash
	def to_stream
		inspect
	end
end


