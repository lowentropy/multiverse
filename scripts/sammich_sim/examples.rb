use! 'rest', 'sammich'
include REST
include Sammich
entity(/sim/) do
	behavior(/should_accept_complaints/) do
		begin
			by, about = UID.random, UID.random
			Complaint.new(by, about).post_to '/grid'.to_store
			true
		rescue
			$env.err $!
			false
		end
	end
end
map_rest
fun(:start) { quit }
