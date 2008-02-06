require 'rubygems'
require 'spec'
require 'src/environment'
require 'src/server'

describe "Behaviour" do
  before :each do 
		@server = Server.new.start
	end
	
	after :each do
		return unless @server
		@server.stop.join(1).each do |exc|
			puts exc
			puts exc.backtrace.map {|l| "\t#{l}"}
		end
  end
  
  it "should call toplevel behavior" do    
    @server.load 'test', "scripts/test/rest/behavior.rb"
		@server.sandbox do
			MV.req 'scripts/test/rest/behavior.rb'
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
