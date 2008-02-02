$: << 'src'
require 'server'
require 'script'

def time(name, &block)
	start = Time.now
	$stdout.write("%10s: " % [name])
	yield
	duration = Time.now - start
	puts("%f s" % [duration])
	duration
end

total = time 'start' do
	@server = Server.new
	@server.start
end

total += time 'read' do
	@script = Script.new
	@script.eval %<
		state :default do
			start do
				MV.map /foo/ do |req|
					MV.log :debug, req.inspect
				end
				goto :wait
			end
		end
		state :wait do
			start do
				MV.pass
				goto :wait
			end
		end
	>
end

total += time 'run' do
	@server.run @script
end

total += time 'stop' do
	@server.stop
end

total += time 'join' do
	@server.join(1).each do |e|
		fail e
		puts e
		puts e.backtrace.map {|l| "\t#{l}"}
	end
end

puts("     total: %f s" % [total])
