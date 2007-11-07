fun(:start) { quit }

class GenericStore
	def initialize
		@items = {}
	end
	def [](k1,k2); @items[k1+k2]; end
	def []=(k1,k2,val); @items[k1+k2] = val; end
	def remove(k1,k2); @items.delete k1+k2; end
end

store(/foo/,GenericStore) do
	entity(/([a-z]+)-([0-9]+)/) do
		path :name, :number
		update {}
		get { "#{name}-#{number}" }
	end
	index { @items }
	find {|name,num| self[name,num]}
	add {|item| self[item.name,item.number] = item}
	delete {|item| self.remove item.name, item.number}
end

class BarEntity
	def render; x; end
end

store(/bar/) do
	entity(/(.+)/, BarEntity) { path :x }
	find {|x| entity.new x }
end

class Baz
	def baz
		'baz'
	end
end

class BazEntity
	def render
		"#{@parent.baz}:#{x}"
	end
end

store(/baz/,Baz) do
	entity(/(.+)/,BazEntity) { path :x }
	find {|x| entity.new x}
end

map_rest
