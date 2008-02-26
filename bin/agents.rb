#! /usr/bin/ruby

$: << File.dirname(__FILE__) + '/../src'

require 'server'
require 'script'

server = Server.new
server.start

server.sandbox do
	MV.req 'scripts/agent.rb'
	ARGV.each do |agent|
		load_agent(agent).load_server
	end
end

server.stop
server.join
