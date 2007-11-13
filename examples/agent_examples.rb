require 'src/ext'
require 'src/environment'
require 'src/server'
require 'src/host'
require 'src/agent'
require 'src/rest/rest'
require 'mongrel'

describe "Agent" do
  before :each do
    begin
      @server = Server.new :log => {:level => :debug}, 'port' => 4000
      @host = @server.localhost
    rescue Exception => e
      puts e
      puts e.backtrace
    end
    @agent = Agent.new('foo') do
      version '2.1.6'
      uid '327A825D-4C37-6915-C0E8-F2DBD77AF170'
      libs
      code
    end
  end
  after :each do
    return unless @server
    @server.shutdown
    @server.join
    # rescue Mongrel::StopServer => e
  end
  
  it "should load agents as agent and add agent" do
    pending "functionality"
    @server.load :test, {}, 'scripts/test/agent.rb'
    @server.start
    sleep 10
    foo = '/agents/foo'.to_entity
    foo.put @agent.to_yaml
    @agent.to_yaml.should == foo.get.to_yaml
  end
  
  it "should add new agent" do
    pending "functionality"
    @server.load :host, {}, 'scripts/agents.rb'
    @server.start
    foo = '/agents/foo'.to_entity
    foo.put @agent.to_yaml
    @agent.to_yaml.should == foo.get.to_yaml
  end
end