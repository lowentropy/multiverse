# declare (publish) the host's identification resource
map :host do
private
	# publish host info/credentials
	fun :declare do
		publish :uid => host.uid, :owner => host.uid,
						:content => host.info.marshal,
						:signed => false, :handler => :add_host
	end

public
	# cache a host: add to the directory
	fun :add do
		host.directory << Message.unmarshal(params[:host])
	end

	fun :ping do
		reply
	end
end
