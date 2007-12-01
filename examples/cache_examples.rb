require 'rubygems'
require 'spec'
require 'src/environment'
require 'src/server'

describe "Cache" do
  before :each do
		begin
			@server = Server.new :log => {:level => :debug}, 'port' => 4000
			@host = @server.localhost
		rescue Exception => e
			puts e
			puts e.backtrace
		end
		@server.start
		@server.sandbox do
			use! 'rest', 'cache'
			@cache = '/cache'.to_store
		end
	end

  after :each do
		return unless @server
		@server.shutdown
		@server.join
	end
	
	it "should index empty cache" do
		# pending "sanity"
		@server.sandbox do
			@cache.index.should == []
			@cache.size.get.should == 0
		end
  end
  
	it "should add and get and delete item" do
		pending "sanity"
		@server.sandbox do
			uid = UID.random
			item = @cache[uid]
			
			lambda { item.get }.should raise_error(REST::RestError, /404/)
			
			item.put 'foo'
			
			@cache.size.get.should == 1
			@cache.index.should == [uid.to_s]
			item.get.should == 'foo'
			
			item.delete
			
			@cache.size.get.should == 0
			@cache.index.should == []
			lambda { item.get }.should raise_error(REST::RestError, /404/)
		end
	end

	it "should allow update by nobody" do	  
		pending "sanity"
		@server.sandbox do
			item = @cache[UID.random]
			item.put 'foo'
			item.get.should == 'foo'
			item.put 'bar'
			item.get.should == 'bar'
		end
	end
	
	it "should allow update by owner" do
		pending "sanity"
		@server.sandbox do
			item = @cache[UID.random]
			item.put 'foo'
			item.get.should == 'foo'
			item.put 'bar', :owner => 'bob'
			item.get.should == 'bar'
			item.put 'baz', :owner => 'bob'
			item.get.should == 'baz'
		end
	end
	
	it "should not allow update by non owner" do
		pending "sanity"
		@server.sandbox do
			item = @cache[UID.random]
			item.put 'foo', :owner => 'bob'
			item.get.should == 'foo'
			lambda { item.put('baz', :owner => 'ted') }.should \
				raise_error(REST::RestError, /401/)
			item.get.should == 'foo'
		end
	end
	
  it "should get uid of cache item" do
		pending "sanity"
		@server.sandbox do
			uid = UID.random
			item = @cache[uid]
			item.put
			item.uid.get.should == uid
			lambda { @cache[UID.random].uid.get }.should \
				raise_error(REST::RestError, /404/)
		end
  end
end
