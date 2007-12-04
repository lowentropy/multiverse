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

	it 'should remember complaints' do
		@server.sandbox do
			by, about = UID.random, UID.random
			grid = '/grid'.to_store
			hash = {:by => by, :about => about}
			grid[by].complaints.post '', hash
			grid[about].complaints.post '', hash
			grid[by].complaints.get.should == [hash]
			grid[about].complaints.get.should == [hash]
			grid[by].complaints.by.get.should == [hash]
			grid[about].complaints.about.get.should == [hash]
			grid[by].complaints.about.get.should == []
			grid[about].complaints.by.get.should == []
		end
	end

end
