use! 'rest'
include REST

store(/grid/, PGrid) do
	attributes :prefix
	find		{|uid| entity.from_path }
	add			{|item| item.update }
	entity(/(uid)/, Item) do
		path :uid, :trailing => :target
		get { internal_redirect }
		update { internal_redirect }
		delete { internal_redirect }
		verb(:post) { internal_redirect }
	end
	store(/links/) do
		find  { entity.from_path }
		entity(/([0-9]+)/) do
			path :level
			get { parent.parent.links(level) }
		end
	end
	behavior(/map/) do
		$env.dbg "MAP: #{params.inspect}" # XXX
		parent.maps << [/#{params[:regex]}/, params[:agent], params[:sub]]
	end
end

map_rest

fun(:start) { quit }
