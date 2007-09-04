log 'requiring host file...'

req File.expand_path(File.dirname(__FILE__) + '/../host.rb')

fun :start do
	Thread.pass
end

log 'mapping test handler...'

map(:test) do
	fun :ping do
		log 'running test...'
	end
end
