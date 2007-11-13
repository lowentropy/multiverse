require 'src/ext'

describe "InstanceExec" do
	before :each do  
		@foo = Foo.new
	end

	def test_should_find_instance_eval_and_exec_similar
		block = proc { @bar }
		
    @foo.instance_eval(&block).should == 216
    @foo.instance_exec(&block).should == 216
	end

	it 'should instance exec with params' do
		block = proc {|n| ([@bar.to_s + '!'] * n).join ' '}
		
		@foo.instance_exec(3, &block).should =='216! 216! 216!'
	end
end

class Foo
	def initialize
		@bar = 216
	end
end