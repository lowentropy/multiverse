$: << 'src'
require 'server'
require 'script'
require 'test'

script_class = ARGV[0] ? TestScript : Script

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
	@script = script_class.new 'test'
	@script.eval <<-END

		state :default do
			start do
				goto :reqtest
			end
		end

		state :reqtest do
			start do
				MV.req "foo.rb"
				MV.log :debug, Foo.new.foo(5)
			end
		end

		state :webtest do
			start do
				MV.map(/^\\/foo$/, proc do |req|
					{:code => 200, :body => req.params.inspect}
				end)
				rep = MV.get 'http://localhost:4000/foo', '', 'text/plain', {'a'=>'b'}, 1
				MV.log :debug, rep.inspect
			end
		end
	END
end

total += time 'run' do
	@server.run @script
end

total += time 'wait' do
	Thread.pass while @script.running?
end

total += time 'stop' do
	@server.stop
end

total += time 'join' do
	@server.join.each do |e|
		fail e
		puts e
		puts e.backtrace.map {|l| "\t#{l}"}
	end
end

puts("     total: %f s" % [total])
