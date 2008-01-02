require 'rubygems'
require 'spec'
require 'src/environment'
require 'src/server'

describe "Store" do
  before :each do
		begin
			@server = Server.new :log => {:level => :fatal}, 'port' => 4000
		rescue Exception => e
			puts e
			puts e.backtrace
		end
		@server.start
		@server.sandbox do
			use! 'rest'
			def cause(code, &block)
				ok = false
				begin
					block.call
				rescue Exception => e
					/#{code}/.should =~ e.message
					ok = true
				end
				ok.should == true
			end
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
		@server.sandbox do
			'/foo'.to_store.post '', :name => 'foo', :number => 216
		end
	end

	it 'should get store entity' do
		@server.load :host, {}, "scripts/test/rest/store.rb"
		@server.sandbox do
			entity = '/foo'.to_store['abc-123']
			entity.put
			
			entity.get.should == 'abc-123'
		end
	end
	
	it 'should automatic entity' do
		@server.load :host, {}, "scripts/test/rest/store.rb"
		@server.sandbox do
			'/bar'.to_store['blah'].get.should == 'blah'
		end
	end

	it 'should auto with builtins and parent' do
		@server.load :host, {}, "scripts/test/rest/store.rb"
		@server.sandbox do
			'/baz/quux'.to_rest.get.should == 'baz:quux'
		end
	end

  it 'should non matching entity' do
		@server.load :host, {}, "scripts/test/rest/store.rb"
		@server.sandbox do
			cause(404) do
				'/foo/foo'.to_rest.get
			end
		end
	end

	it 'should add and delete' do
		@server.load :host, {}, "scripts/test/rest/store.rb"
		@server.sandbox do
			e = '/foo'.to_store['abc-123']
			cause(404) { e.get }
			e.put
			e.get.should == 'abc-123'
			e.delete
			cause(404) { e.get }
		end
	end
end
