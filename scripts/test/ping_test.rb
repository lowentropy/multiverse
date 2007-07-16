req File.expand_path(File.dirname(__FILE__) + '/../host/ping.rb')

fun :start do
	exit
end

map(:test) do
	map(/ping/) do
		fun :test do
			raise 'TODO'
		end
	end
end
