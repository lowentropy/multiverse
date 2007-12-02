require 'rubygems'
require 'spec'
require 'src/environment'
require 'src/server'

describe "Behaviour" do
  before :each do 
		begin
			@server = Server.new :log => {:level => :error}, 'port' => 4000
		rescue Exception => e
			puts e
			puts e.backtrace
		end
		@server.start
		@server.sandbox do
			use! 'rest'
		end
	end
	
	after :each do
		return unless @server
		@server.shutdown
		@server.join
  end
  
  it "should call toplevel behavior" do    
    @server.load :host, {}, "scripts/test/rest/behavior.rb"
		@server.sandbox do
			'/foo'.to_behavior.call('', :a => 1, :b => 2).should == 3
		end
  end
  
  it "should call dynamic entity behavior" do
		@server.load :host, {}, "scripts/test/rest/behavior.rb"
		@server.sandbox do
			res = '/baz'.to_store['gir'].foo.post '', :a => 1, :b => 2
			res.should == 'gir: 3'
		end
  end
  
  it "should call store behavior" do
    @server.load :host, {}, "scripts/test/rest/behavior.rb"
		@server.sandbox do
		 '/bar'.to_store.foo.post('', :a => 1, :b => 2).should == 3
		end
  end
end
