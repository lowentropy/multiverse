use! 'rest', 'sammich'
include REST
include Sammich
entity(/sim/) do
	behavior(/should_accept_complaints/) do
		begin
			by, about = UID.random, UID.random
			Complaint.new(by, about).post_to '/grid'.to_store
			i1 = "/sammich/#{by}/complaints".to_store.index
			i2 = "/sammich/#{about}/complaints".to_store.index
			if i1.size != 1 or i2.size != 1
				$env.err "wrong sizes"
			elsif i1[0][:by] != by or i1[0][:about] != about
				$env.err "wrong by complaint"
			elsif i2[0][:by] != by or i2[0][:about] != about
				$env.err "wrong about complaint"
			else
				return true
			end
			$env.err "I1: #{i1.inspect}"
			$env.err "I2: #{i2.inspect}"
			false
		rescue
			$env.err $!
			false
		end
	end
end
map_rest
fun(:start) { quit }
