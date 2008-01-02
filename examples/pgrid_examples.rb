require 'rubygems'
require 'spec'
require 'src/environment'
require 'src/server'

describe "PGrid" do
  before :each do
		begin
			@server = Server.new :log => {:level => :error}, 'port' => 4000
		rescue Exception => e
			puts e
			puts e.backtrace
		end
		@server.start
		@server.sandbox do
			use! 'rest', 'pgrid', 'cache'
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
	
	it 'should have no beginning links' do
		#pending 'sanity'
		@server.sandbox do
			'/grid'.to_store['links/216'].get.should == {}
		end
	end

	it 'should return 404 with no links' do
		#pending 'sanity'
		@server.sandbox do
			cause(404) do
				'/grid'.to_store[UID.random].get
			end
		end
	end

	it 'should travel from grid to cache' do
		#pending 'sanity'
		@server.sandbox do
			uid = UID.random
			'/grid'.to_store[uid].put 'foo'
			'/cache'.to_store.index.should == [uid]
			'/cache'.to_store[uid].get.should == 'foo'
			'/grid'.to_store[uid].get.should == 'foo'
		end
	end

	it 'should travel from cache to grid' do
		#pending 'sanity'
		@server.sandbox do
			uid = UID.random
			'/cache'.to_store[uid].put 'foo'
			'/grid'.to_store[uid].get.should == 'foo'
		end
	end

	it 'should interface with solver' do
		#pending 'sanity'
		@server.sandbox do
			use! 'solver'
			uid = UID.random
			solver = '/grid'.to_store[uid].solver
			solver.put '2+2'
			solver.get.should == 4
		end
	end

end
