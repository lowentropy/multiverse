require 'rubygems'
require 'spec'
require 'src/server'
require 'src/script'

describe "Entity" do
  before :each do
		@server = Server.new
		@host = 'localhost'
		@script = Script.new 'test'
		@server.start
		@script.server = @server
		@script.eval <<-END
			MV.req 'scripts/ext.rb'
			MV.req 'scripts/agent.rb'
			load_agent('rest').load_client
		END
	end

  after :each do
		@server.stop
		errs = @server.join
		if errs.size > 1
			errs.each do |e|
				puts e.message
				puts e.backtrace
				puts ""
			end
		elsif errs.any?
			fail errs[0]
		end
	end

	def req(file)
		@script.eval "MV.req 'scripts/test/rest/#{file}'", "(req)"
	end

  it 'should run top entity through rest' do
		req 'top_entity.rb'
		@script.eval nil, "(test)" do
			state :default do
				start do
					MV.log :info, '/rest/test'.to_behavior.post.inspect
				end
			end
		end
		@server.run @script
	end

#	it 'should set and get entity attributes' do
#		pending "conversion"
#		@server.load :host, {}, "scripts/test/rest/entity_attr.rb"
#		@server.sandbox do
#			foo = '/foo'.to_entity
#
#			%w(a b c).each do |attribute|
#				field = foo.send attribute
#				field.set 216
#				field.get.should == '216'
#			end
#		end
#	end
#	
#  it 'should set attributes and get entity' do
#		pending "conversion"
#    @server.load :host, {}, "scripts/test/rest/entity_attr.rb"
#  	@server.sandbox do
#			foo = '/foo'.to_entity
#			foo.a.set 1
#			foo.b.set 2
#			foo.c.set 3
#  
#			foo.get.should == {:a => '1', :b => '2', :c => '3'}
#		end
#  end
#  
#	it 'should active entity' do
#		pending "conversion"
#		@server.load :host, {}, "scripts/test/rest/entity_active.rb"
#		@server.sandbox do
#			foo = '/foo'.to_entity
#			foo.a.set 3
#			foo.b.set 7
#
#			foo.c.get.should == 21
#		end
#	end
#	
#	it 'should dynamic entity name' do
#		pending "conversion"
#		@server.load :host, {}, "scripts/test/rest/entity_dynamic_name.rb"
#		@server.sandbox do
#			%w(/foo /bar /baz /bazzz).each do |name|
#				name.to_entity.get.should == '216'
#			end
#
#			%w(/asdf /monkey /bazzzz).each do |name|
#				cause(404) do
#					name.to_entity.get
#					puts "#{name} succeeded!"
#				end
#			end
#		end
#	end
#
#	it 'should parse uri' do
#		pending "conversion"
#		@server.load :host, {}, "scripts/test/rest/entity_parse_uri.rb"
#		@server.sandbox do
#			10.times do
#				num = rand(100000).to_s
#				"/a#{num}z".to_entity.get.should == num
#			end
#		end
#	end
#	
#  it 'should sub entity' do
#		pending "conversion"
#		@server.load :host, {}, "scripts/test/rest/entity_sub.rb"
#		@server.sandbox do
#			(foo = '/foo'.to_entity).get.should == 'foo'
#			foo.bar.get.should == 'bar'
#			foo.bar.baz.get.should == 'baz'
#		end
#	end
end
