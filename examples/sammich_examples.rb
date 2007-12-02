require 'rubygems'
require 'spec'
require 'src/environment'
require 'src/server'

describe "Sammich" do
  before :each do
		begin
			@server = Server.new :log => {:level => :debug}, 'port' => 4000
		rescue Exception => e
			puts e
			puts e.backtrace
		end
		@server.start
		@server.sandbox do
			use! 'rest', 'pgrid', 'sammich', 'sammich_sim'
			@grid = '/grid'.to_store
		end
	end

	after :each do
		return unless @server
		@server.shutdown
		@server.join
  # rescue Mongrel::StopServer => e
	end
	
	it 'should give an unknown uid 0 trust' do
		@server.sandbox do
			@grid[UID.random].rep.get.should == 0
		end
	end

	%w(accept_complaints
	   ).each do |action|
		it('should ' + action.gsub(/_/,' ')) do
			@server.sandbox do
				"/sim/should_#{action}".to_behavior.call.should == true
			end
		end
	end

end
