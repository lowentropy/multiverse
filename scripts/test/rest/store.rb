fun(:start) { quit }

class GenericStore
	def initialize
		@items = {}
	end
	def [](k1,k2); @items[k1+k2]; end
	def []=(k1,k2,val); @items[k1+k2] = val; end
end

store(/foo/,GenericStore) do
	entity(/([a-z]+)-([0-9]+)/) do
		path :name, :number
	end
	index { @items }
	find {|name,num| self[name,num]}
	add {|item| self[item.name,item.number] = item}
end

map_rest
