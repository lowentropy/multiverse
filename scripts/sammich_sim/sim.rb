use! 'sammich'
include Sammich

class ::Fixnum
	def of(&block)
		Array.new(self, &block)
	end
end

fun(:start) do
	cheaters = 5.of  { UID.random }
	goodguys = 30.of { UID.random }
	goodguys.each do |goodguy|
		cheaters.each do |cheater|
			$stdout.puts "#{goodguy} is buying."
			next unless rand <= 0.3
			$stdout.puts "#{cheater} is cheating!"
			if rand <= 1.0
				c1 = Complaint.new goodguy, cheater
				c1.post_to '/sammich'.to_store
			end
			if rand <= 1.0
				c2 = Complaint.new cheater, goodguy
				c2.post_to '/sammich'.to_store
			end
		end
	end
	victim = UID.random
	10.times do
		$stdout.puts "#{victim} is being attacked!"
		uid = UID.random
		Complaint.new(uid, victim).post_to '/sammich'.to_store
		Complaint.new(victim, uid).post_to '/sammich'.to_store
	end
	cheaters.map! {|uid| r = uid.rep; r.update; r}
	goodguys.map! {|uid| r = uid.rep; r.update; r}
	re = (cheaters+goodguys).map {|r| r.about.size}.sum
	fi = (cheaters+goodguys).map {|r| r.by.size}.sum
	n = cheaters.size + goodguys.size
	ra, fa = re.to_f / n.to_f, fi.to_f / n.to_f
	cheaters.each do |rep|
		$stdout.puts "cheater rep = #{rep.reputation(2,ra,fa)}"
	end
	goodguys.each do |rep|
		$stdout.puts "goodguy rep = #{rep.reputation(2,ra,fa)}"
	end
	$stdout.puts "victim rep = #{victim.rep.reputation(1,ra,fa)}"
	quit
end
