require 'rubygems'
require 'spec'
require 'src/environment'
require 'src/server'

describe "Sammich" do
  before :each do
		begin
			@server = Server.new :log => {:level => :error}, 'port' => 4000
		rescue Exception => e
			puts e
			puts e.backtrace
		end
		@server.start
		@server.sandbox do
			use! 'sammich'
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
	end

end
