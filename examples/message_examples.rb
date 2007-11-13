require 'src/message'

describe Message do
  before :each do
		@msg = Message.new :foo, 'bar'.to_host, 'baz', {}
	end
	
	it 'should pass integers' do
		@msg[:an_int] = 216
		
    reload[:an_int].should == 216
	end
	
	it 'should pass symbols' do
		@msg[:a_sym] = :symbol
		
    reload[:a_sym].should == :symbol
	end
	
	it 'should pass floats' do
		@msg[:a_float] = 3.14
		
    @msg[:a_float].should == 3.14
	end
	
	it 'should pass strings' do
		@msg[:param_1] = 'abc'
		@msg[:param_2] = 'def'
		msg = reload
		
    msg.command.should == :foo
    msg.host.to_s.should == 'bar:4000'
    msg.url.should == 'baz'
    msg[:param_1].should == 'abc'
    msg[:param_2].should == 'def'
	end
	
	it 'should pass multiline hosts and urls' do
		@msg.host = "the\nhost"
		@msg.url = "the\nurl"
		msg = reload
		
    msg.host.to_s.should == "the\nhost:4000"
    msg.url.should == "the\nurl"
	end
end
  
def reload
	Message.unmarshal @msg.marshal
end