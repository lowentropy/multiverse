#! /usr/bin/ruby

$: << File.dirname(__FILE__)

require 'webrick'

class Server < WEBrick::HTTPServlet::AbstractServlet

	def initialize(server, *options)
		super(server)
		@env = {}
	end

	def self.get_instance(server, *options)
		@inst ||= Server.new server, *options
	end

	def load(env=:host, options={}, *scripts)
		create_env(env, options) unless @env[env]
		scripts.each do |script|
			msg = Message.new(:load, nil, nil, :name => script)
			@env[env].write msg
			reply = wait_for_reply_to msg
			raise reply[:error] if reply[:error]
		end
	end

	def create_env(env, options)
		path = File.dirname(__FILE__)
		lang = options[:lang] || :ruby
		command = case lang
			when :ruby then "ruby #{path}/ruby-script.rb"
			else raise "unknown script language #{lang}"
		end
		io = IO.popen(command, 'w+')
		@env[env] = MessagePipe.new io, io
	end

	def self.start(config=nil, *options)
		server = WEBrick::HTTPServer.new
		server.mount '/', Server
		trap 'INT' { server.shutdown }
		server.start
	end

	def do_GET(request, response)
	end

	def do_PUT(request, response)
	end

	def do_POST(request, response)
	end

end
