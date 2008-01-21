$: << 'src'
require 'server'
require 'script'

def time(name, &block)
	start = Time.now
	$stdout.write("%10s: " % [name])
	yield
	puts("%f s" % [Time.now - start])
end

time 'start' do
	@server = Server.new
	@server.start
end

time 'read' do
	@script = Script.new
	@script.eval %{
		state :default do
			start do
				MV.log :debug, 'foo'
				goto :default
			end
		end
	}
end

time 'run' do
	@server.run @script
end

time 'stop' do
	@server.stop
end

time 'join' do
	@server.join(1).each do |e|
		fail e
		puts e
		puts e.backtrace.map {|l| "\t#{l}"}
	end
end
