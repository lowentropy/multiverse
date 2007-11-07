fun(:start) { quit }

fun(:add) do |params|
	params[:a].to_i + params[:b].to_i
end

behavior(/foo/) do
	$env.add params
end

store(/bar/) do
	behavior(/foo/) do
		$env.add params
	end
end

store(/baz/) do
	find {|x| entity.from_path x }
	entity(/(.+)/) do
		path :x
		behavior(/foo/) do
			"#{@parent.x}: #{$env.add(params)}"
		end
	end
end

map_rest
