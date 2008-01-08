require 'rubygems'
require 'spec'
require 'src/script'

describe "Scripts" do

	before :each do
		@script = Script.new
	end
	
  it 'should remember state info' do
		@script.eval %{
			state :default do
				start do
					unless @next
						@next = true
						goto :b
					end
					216
				end
			end
			state :b do
				start do
					goto :default
				end
			end
		}
		@script.run.should == 216
	end

	it 'should allow explicit states' do
		@script.state :default do
			start do
				goto :b
			end
		end
		@script.state :b do
			start do
				216
			end
		end
		@script.run.should == 216
	end

	it 'should not remember definer methods' do
		@script.eval %{
			state :default do
				start do
					reset
					start do
						216
					end
					goto :default
				end
			end
		}
		proc {@script.run}.should raise_error
	end

	it 'should not evaluate code after a goto' do
		@script.eval %{
			state :default do
				start do
					unless @ran
						@ran = true
						goto :default
						raise 'error'
					end
					216
				end
			end
		}
		proc do
			@script.run.should == 216
		end.should_not raise_error
	end

end
