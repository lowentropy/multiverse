fun :start do
	Thread.pass
end

@mutex = Mutex.new
@list = []
@highest = 0

listen :order do
	@mutex.lock
	while (params[:num] - @highest) > 1
		@mutex.unlock
		Thread.yield
		@mutex.lock
	end
	@highest = params[:num]
	@mutex.unlock
end

listen :list do
	reply :body => @list.inspect
end
