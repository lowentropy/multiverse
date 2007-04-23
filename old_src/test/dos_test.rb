#! /usr/bin/ruby

class ::Thread
	class CritContainer
		def initialize(crit)
			@crit = crit
		end
		def set(*args)
			raise "safe threads can't go critical" if $SAFE > 0
			@crit.call *args
		end
		def instance_variable_get(*args)
			raise "somebody's trying to be naughty"
		end
	end
	@@crit = CritContainer.new(method(:critical=))
	def self.critical=(*args)
		@@crit.set *args
	end
	def abort_on_exception=(*args)
		raise "somebody's trying to be naughty"
	end
	def self.abort_on_exception=(*args)
		raise "somebody's trying to be naughty"
	end
end

puts "starting 1: critical="
thread = Thread.new do
	$SAFE = 4
	
	begin
		Thread.critical = true
	rescue
	end

	begin
		Thread.send(:class_variable_get, :@@crit).set true
	rescue
	end

	begin
		Thread.send(:class_variable_get, :@@crit).send(
			:instance_variable_get, :@crit).call true
	rescue
	end

	sleep 2
end
thread.join 1
unless thread.alive?
	puts "failed: thread's dead"
	exit
end

begin
	Thread.critical = true
	Thread.critical = false
rescue
	puts "failed: unsafe can't set critical"
	exit
end

puts "starting 2: abort_on_exception="
Thread.new do
	begin
		Thread.current.abort_on_exception = true
	rescue
	end

	begin
		Thread.abort_on_exception = true
	rescue
	end

	raise "failed: aborting program"
end
sleep 1
