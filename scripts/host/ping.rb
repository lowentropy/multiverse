map :host do
	# reply to a ping
	fun :ping do
		reply
	end

private

	# send a ping to the target and wait for the reply
	# returns the loop time
	fun :send_ping do
		msg = params[:host].to_host.post '/ping', :time => Time.now
		loop_time = msg[:time] - msg[:receive_time]
		reply :loop_time => loop_time
	end
end
