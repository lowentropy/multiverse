require 'src/environment'
require 'src/server'

describe "Cache" do
  before :each do
		begin
			@server = Server.new :log => {:level => :fatal}, 'port' => 4000
			@host = @server.localhost
		rescue Exception => e
			puts e
			puts e.backtrace
		end
		@server.load :host, {}, "scripts/cache.rb"
		@server.start
		@cache = '/cache'.to_store
	end

  after :each do
		return unless @server
		@server.shutdown
		@server.join
  # rescue Mongrel::StopServer => e
	end
	
	it "should index empty cache" do
	  @cache.index.should == []
	  @cache.size.get.should == 0
  end
  
	it "should add and get and delete item" do
		uid = UID.random
		item = @cache[uid]
		
		lambda { item.get }.should raise_error(REST::RestError, /404/)
		
		item.put '', :data => 'foo'
		
		@cache.size.get.should == 1
		@cache.index.should == [uid.to_s]
		item.get.should == 'foo'
		
		item.delete
		
		@cache.size.get.should == 0
		@cache.index.should == []
		lambda { item.get }.should raise_error(REST::RestError, /404/)
	end
	it "should allow update by nobody" do	  
		item = @cache[UID.random]
		item.put '', :data => 'foo'
		item.get.should == 'foo'
		item.put '', :data => 'bar'
		item.get.should == 'bar'
	end
	
	it "should allow update by owner" do
		item = @cache[UID.random]
		item.put '', :data => 'foo'
		item.get.should == 'foo'
		item.put '', :data => 'bar', :owner => 'bob'
		item.get.should == 'bar'
		item.put '', :data => 'baz', :owner => 'bob'
		item.get.should == 'baz'
	end
	
	it "should not allow update by non owner" do
		item = @cache[UID.random]
		item.put '', :data => 'foo', :owner => 'bob'
		item.get.should == 'foo'
    lambda { item.put('', :data => 'baz', :owner => 'ted') }.should raise_error(REST::RestError, /401/)
    item.get.should == 'foo'
	end
	
  it "should get uid of cache item" do
    uid = UID.random
    item = @cache[uid]
    item.put
    item.uid.get.should == uid
    lambda { @cache[UID.random].uid.get }.should raise_error(REST::RestError, /404/)
  end
end