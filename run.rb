$: << 'src'
require 'server'

@server = Server.new :log => {:level => :error}, 'port' => 4000
@server.start
@server.sandbox do
	use! 'rest', 'pgrid', 'sammich', 'sammich_sim'
	puts "type 'quit'" until /quit/i =~ $stdin.gets
end
@server.shutdown
@server.join
