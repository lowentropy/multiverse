require 'rubygems'
require 'spec'
require 'src/environment'
require 'src/server'
require 'src/rest/rest'

describe "PGrid" do
  before :each do
		begin
			@server = Server.new :log => {:level => :error}, 'port' => 4000
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
	
	it 'should load pgrid agent' do
		#pending 'sanity'
		@server.load :test, {}, "scripts/pgrid/agent.rb"
		@server.start true, :test
	end

	it 'should have no beginning links' do
		#pending 'sanity'
		@server.load :test, {}, "scripts/pgrid/agent.rb"
		@server.start true, :test
		'/grid'.to_store['links/216'].get.should == {}
	end

	it 'should return 404 with no links' do
		#pending 'sanity'
		@server.load :test, {}, "scripts/pgrid/agent.rb"
		@server.load :test, {}, "scripts/cache/agent.rb"
		@server.start true, :test
		proc do
			begin
				'/grid'.to_store[UID.random].get
			rescue REST::RestError => e
				e.code.should == 404
				fail
			end
		end.should raise_error(REST::RestError)
	end

	it 'should travel from grid to cache' do
		#pending 'sanity'
		@server.load :test1, {}, "scripts/pgrid/agent.rb"
		@server.load :test2, {}, "scripts/cache/agent.rb"
		@server.start true, :test2
		uid = UID.random
		'/grid'.to_store[uid].put '', :data => 'foo'
		'/cache'.to_store.index.should == [uid]
		'/cache'.to_store[uid].get.should == 'foo'
		'/grid'.to_store[uid].get.should == 'foo'
	end

	it 'should travel from cache to grid' do
		#pending 'sanity'
		@server.load :test1, {}, "scripts/pgrid/agent.rb"
		@server.load :test2, {}, "scripts/cache/agent.rb"
		@server.start true, :test2
		#uid = UID.random
		'/cache'.to_store[uid].put '', :data => 'foo'
		'/grid'.to_store[uid].get.should == 'foo'
	end

end
