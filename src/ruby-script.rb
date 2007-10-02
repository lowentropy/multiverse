#! /usr/bin/ruby

require 'socket'

$: << File.dirname(__FILE__)

require 'environment'

server = nil

input, output =
	if (index = $*.index('--port'))
		port = $*[index+1].to_i
		server = TCPServer.new port
		io = server.accept
		[io, io]
	else
		[$stdin, $stdout]
	end
	

env = Environment.new input, output

trap 'INT' do
	env.shutdown!
	env.join 0.1
end
env.run
env.join

server.close if server unless server.closed?
