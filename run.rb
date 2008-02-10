$: << 'src'
require 'server'
require 'script'
require 'test'

script_class = ARGV[0] ? TestScript : Script

$code = <<-END1
	$code = <<-END2
		class X
			def self.baz
				raise 'baz'
			end
		end
		$third = <<-END3
			class X
				def self.barf
					raise 'barf'
				end
			end
		END3
		Foo.eval 'level3', $third
	END2
	class X
		def self.foo
			raise 'foo'
		end
	end
	Foo.eval 'level2', $code
	class X
		def self.bar
			raise 'bar'
		end
	end
END1

module Foo
	def self.eval(name, text)
		$script.eval text, name
	end
end

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
	$script = script_class.new 'test'
	box = $script.instance_variable_get :@sandbox
	box.ref Foo
	$script.eval $code, 'level1'
	$script.eval <<-END
		state :default do
			start do
				X.baz
			end
		end
	END
	puts "files: #{$script.instance_variable_get(:@files).inspect}"
end

total += time 'run' do
	@server.run $script
end

total += time 'wait' do
	Thread.pass while $script.running?
end

total += time 'stop' do
	@server.stop
end

total += time 'join' do
	@server.join.each do |e|
		fail e
	end
end

puts("     total: %f s" % [total])
