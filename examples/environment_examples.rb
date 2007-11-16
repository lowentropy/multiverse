require 'rubygems'
require 'spec'
require 'src/environment'

describe "Environment" do
  before :each do
		@in_buf, @out_buf = Buffer.new, Buffer.new
		# FIXME: this initialization sequence is STUPID.
		@env = Environment.new nil, nil, true
		@env.set_io @out_buf, @in_buf, 'MemoryPipe'
		@env.sandbox_check = false
		@pipe = MemoryPipe.new @in_buf, @out_buf
		@env.add_script 'default', 'fun(:start) { quit }'
		@env.externalize_sandbox
	end
	
  it 'should join' do
		start = Time.now
	  lambda {
			@env.run!
			sleep 1
			@env.shutdown!
			@env.join(0.3)
		}.should_not raise_error
		time = Time.now - start
    time.should < 4
	end
	
	it 'should fun return value' do
		@env.add_script 'foo', 'fun(:foo) { 216 }'
    @env.foo.should == 216
	end
	
	it 'should pipe out external' do
		@env.run!
		"foo".to_host.put '/test', :param => 'value', :message_id => 0
		@pipe.read # :started
    @pipe.read.to_s.should =~ /PUT http:\/\/foo:4000\/test:\{(:[a-z_]+=>("value"|0)(, )?)+\}/
		@env.shutdown!
		@env.join 0
	end
	
  it 'should pipe out internal' do
		@env.add_script 'test', <<END
fun :test do
	'foo'.to_host.put '/test', :param => 'value', :message_id => 0
end
END
		@env.run!
		@env.test
		@pipe.read # :started
    @pipe.read.to_s.should =~ /PUT http:\/\/foo:4000\/test:\{(:[a-z_]+=>("value"|0)(, )?)+\}/
		@env.shutdown!
		@env.join 0
	end
end
