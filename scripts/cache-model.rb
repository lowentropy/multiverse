class Cache
	def initialize
		@items = {}
		#timer(:interval => config[:interval]) do
		#	cleanup
		#end
	end
	def size
		@items.size
	end
	def cleanup
		@items.sort[config[:max_items]..-1].each do |item|
			@items.delete(item.uid).store
		end
	end
end

class Cache::Item
	attr_reader :last_use
	def initialize
		@last_use = Time.now
		@loaded = false
	end
	def <=>(item)
		@last_use <=> item.last_use
	end
	def store
		#$env.open "cache/#{uid}" do |f|
		#	f.write to_yaml
		#end
	end
	def load
		# TODO: load from file(uid).read
	end
end
