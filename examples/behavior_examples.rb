require 'src/environment'
require 'src/server'

describe "Behaviour" do
  before :each do 
		begin
			@server = Server.new :log => {:level => :fatal}, 'port' => 4000
		rescue Exception => e
			puts e
			puts e.backtrace
		end
	end
	
	after :each do
		return unless @server
		@server.shutdown
		@server.join
  end
  
  it "should call toplevel behavior" do    
    @server.load :host, {}, "scripts/test/rest/behavior.rb"
    @server.start
    '/foo'.to_behavior.call('', :a => 1, :b => 2).should == 3
  end
  
  it "should call dynamic entity behavior" do
		@server.load :host, {}, "scripts/test/rest/behavior.rb"
		@server.start
		res = '/baz'.to_store['gir'].foo.post '', :a => 1, :b => 2
		res.should == 'gir: 3'
  end
  
  it "should call store behavior" do
    @server.load :host, {}, "scripts/test/rest/behavior.rb"
    @server.start
   '/bar'.to_store.foo.post('', :a => 1, :b => 2).should == 3
  end
end
