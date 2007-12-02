require 'rubygems'
require 'spec'
require 'src/ext'
require 'src/environment'
require 'src/server'

describe "Entity" do
  before :each do
		begin
			@server = Server.new :log => {:level => :fatal}, 'port' => 4000
			@host = @server.localhost
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
	
  it 'should run top entity through rest' do
		@server.load :host, {}, "scripts/test/rest/top_entity.rb"
		code, response = @server.post @host, '/rest/test'
    code.should == 200
	end

	it 'should set and get entity attributes' do
		@server.load :host, {}, "scripts/test/rest/entity_attr.rb"
		@server.sandbox do
			foo = '/foo'.to_entity

			%w(a b c).each do |attribute|
				field = foo.send attribute
				field.set 216
				field.get.should == '216'
			end
		end
	end
	
  it 'should set attributes and get entity' do
    @server.load :host, {}, "scripts/test/rest/entity_attr.rb"
  	@server.sandbox do
			foo = '/foo'.to_entity
			foo.a.set 1
			foo.b.set 2
			foo.c.set 3
  
			foo.get.should == {:a => '1', :b => '2', :c => '3'}
		end
  end
  
	it 'should active entity' do
		@server.load :host, {}, "scripts/test/rest/entity_active.rb"
		@server.sandbox do
			foo = '/foo'.to_entity
			foo.a.set 3
			foo.b.set 7

			foo.c.get.should == 21
		end
	end
	
	it 'should dynamic entity name' do
		@server.load :host, {}, "scripts/test/rest/entity_dynamic_name.rb"
		@server.sandbox do
			%w(/foo /bar /baz /bazzz).each do |name|
				name.to_entity.get.should == '216'
			end

			%w(/asdf /monkey /bazzzz).each do |name|
				cause(404) do
					name.to_entity.get
					puts "#{name} succeeded!"
				end
			end
		end
	end

	it 'should parse uri' do
		@server.load :host, {}, "scripts/test/rest/entity_parse_uri.rb"
		@server.sandbox do
			10.times do
				num = rand(100000).to_s
				"/a#{num}z".to_entity.get.should == num
			end
		end
	end
	
  it 'should sub entity' do
		@server.load :host, {}, "scripts/test/rest/entity_sub.rb"
		@server.sandbox do
			(foo = '/foo'.to_entity).get.should == 'foo'
			foo.bar.get.should == 'bar'
			foo.bar.baz.get.should == 'baz'
		end
	end
end
