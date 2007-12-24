$: << 'src'
require 'server'

# comment

@server = Server.new :log => {:level => :debug}, 'port' => 4000
@server.start
@server.sandbox do
	use! 'rest', 'pgrid', 'sammich', 'web', 'util'
	puts "type 'quit'" until /quit/i =~ $stdin.gets
end
@server.shutdown
@server.join
