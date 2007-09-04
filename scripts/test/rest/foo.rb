fun :start do
	quit
end

map :rest do
	fun :test do
		log "we did a log, all right!"
	end
end
