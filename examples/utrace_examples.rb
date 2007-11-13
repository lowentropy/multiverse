require 'src/untrace'
require 'src/environment'

describe "Utrace" do
  it 'should untrace' do
    begin
      foo
    rescue
      $!.backtrace.join.index('foo').should be_nil
      $!.backtrace.join.index('bar').should_not be_nil
      $!.to_s.index('baz').should_not be_nil
    else
      fail
    end
  end
  
	it 'should env untrace' do
    # pending 'functionality'
    begin
      @env = Environment.new $stdin, $stdout, true
      @env.sandbox_check = false
      @env.add_script 'test', <<END
fun :foo do 
  raise "foo"
end
fun :bar do
  foo
end
fun :baz do
  bar
end
END
      @env.baz
    rescue RuntimeError => e
      e.should_not be_nil
      e.backtrace[0].should == "test:2:in `foo'"
      e.backtrace[1].should == "test:5:in `bar'"
      e.backtrace[2].should == "test:8:in `baz'"
    else
      fail
    end
	end
end

def foo
  untraced(1) do
    bar
  end
end

def bar
  raise 'baz'
end
