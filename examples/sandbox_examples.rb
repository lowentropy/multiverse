require 'rubygems'
require 'spec'
require 'src/sandbox'

describe "Sandbox" do
  before :each do
		@sandbox = Sandbox.new
	end
	
	it 'should safe' do
		# arguments to pass into thread
		block = [].taint
		kind_of = proc {|k,o| o.should be_kind_of(k)}
		is_nil = proc {|o| o.should be_nil}

		# set up SAFE=4 -level blocks
		Thread.new(block,kind_of,is_nil) do |block,assert_kind_of,assert_nil|
			$SAFE = 4
			block << proc { $stdout.write '' }
    	block << proc { @foo = 'foo' }
      block << proc { assert_nil @sandbox }
      block << proc { assert_kind_of.call Sandbox, self }
		end.join
		
		# no printing in safe blcok
		lambda {
			@sandbox.sandbox &block[0]
		}.should raise_error(SecurityError)

		# no out-of-scope access in sandbox
		lambda {
			@sandbox.sandbox &block[2]
		}.should raise_error(NoMethodError)

		# sandbox writable
		lambda {
			@sandbox.sandbox &block[1]
		}.should_not raise_error

		# sandbox 'self' is correct
		lambda {
			@sandbox.sandbox &block[3]
		}.should_not raise_error

		# SAFE-level doesn't go out of scope
		lambda {
			$stdout.write ''
		}.should_not raise_error

	end
	
	it 'should function' do
		@sandbox.delegate :foo, self
		
    @sandbox.foo.should == 216
	end
	
	it 'should two levels' do
		val = []
		@sandbox.delegate :foo, self
		@sandbox.delegate :bar, self
		
    @sandbox.bar.should == 216
	end
end

def foo
	216
end

def bar
	foo
end
