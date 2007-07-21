req File.expand_path(File.dirname(__FILE__) + '/../host/ping.rb')

fun :start do
	Thread.pass
end

log 'mapping test handler...'

map(:test) do
	map(/ping/) do
		fun :test do
			log 'running test...'
			raise 'TODO'
		end
	end
end
