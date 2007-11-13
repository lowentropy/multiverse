require 'src/environment'
require 'src/server'

describe "Script" do
  before :each do
		@server = Server.new :log => {:level => :fatal}, 'port' => 4000
    @host = @server.localhost
	end

	after :each do
		return unless @server
		@server.shutdown
		@server.join
  # rescue Mongrel::StopServer => e
	end
  
  it 'should ping successfully in fifo mode' do
    @server.load :host, {:mode => 'fifo'}, 'scripts/test/ping_test.rb'
  	@server.start

    @server.post(@host, '/ping').first.should == 200
  end

  it 'should ping successfully in net mode' do
    @server.load :host, {:mode => 'net'}, 'scripts/test/ping_test.rb'
  	@server.start

    @server.post(@host, '/ping').first.should == 200
  end

  it 'should ping successfully in mem mode' do
    @server.load :host, {:mode => 'mem'}, 'scripts/test/ping_test.rb'
  	@server.start

    @server.post(@host, '/ping').first.should == 200
  end
end