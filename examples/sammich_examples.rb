require 'rubygems'
require 'spec'
require 'src/environment'
require 'src/server'
require 'src/rest/rest'

describe "Sammich" do
  before :each do
		begin
			@server = Server.new :log => {:level => :error}, 'port' => 4000
			@host = @server.localhost
		rescue Exception => e
			puts e
			puts e.backtrace
		end
	end

	after :each do
		return unless @server
		@server.shutdown
		@server.join
  # rescue Mongrel::StopServer => e
	end
	
	it 'should load sammich agent' do
		#pending 'sanity'
		@server.load :test, {}, "scripts/sammich/agent.rb"
		@server.start true, :test
	end

end
