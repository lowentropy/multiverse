require 'src/environment'
require 'src/server'

describe "Store" do
  before :each do
		begin
			@server = Server.new :log => {:level => :fatal}, 'port' => 4000
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
	
	it 'should load store' do
		@server.load :agents, {}, "scripts/test/rest/store.rb"
		@server.start true, :agents
		'/foo'.to_store.post '', :name => 'foo', :number => 216
	end

	it 'should get store entity' do
		@server.load :host, {}, "scripts/test/rest/store.rb"
		@server.start
		entity = '/foo'.to_store['abc-123']
		entity.put
		
    entity.get.should == 'abc-123'
	end
	
	it 'should automatic entity' do
		@server.load :host, {}, "scripts/test/rest/store.rb"
		@server.start

    '/bar'.to_store['blah'].get.should == 'blah'
	end

	it 'should auto with builtins and parent' do
		@server.load :host, {}, "scripts/test/rest/store.rb"
		@server.start
		
    '/baz/quux'.to_rest.get.should == 'baz:quux'
	end

  it 'should non matching entity' do
		@server.load :host, {}, "scripts/test/rest/store.rb"
		@server.start
		
		lambda {
			'/foo/foo'.to_rest.get
		}.should raise_error(REST::RestError)
	end

	it 'should add and delete' do
		@server.load :host, {}, "scripts/test/rest/store.rb"
		@server.start
		e = '/foo'.to_store['abc-123']
		
		lambda { e.get }.should raise_error(REST::RestError)
		lambda { e.put }.should_not raise_error
		
		e.get.should == 'abc-123'
		
		lambda { e.delete }.should_not raise_error
		lambda { e.get }.should raise_error(REST::RestError)
	end
end