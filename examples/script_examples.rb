require 'rubygems'
require 'spec'
require 'src/script'

describe "Scripts" do
	
  it 'should remember state info' do
		s = Script.new
		s.eval %{
			state :a do
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
					goto :a
				end
			end
		}
		s.run.should == 216
	end

	it 'should reset at define-time' do
		s = Script.new
		s.eval %{
			state :a do
				start do
					1
				end
			end
			reset
			state :b do
				start do
					2
				end
			end
		}
		s.run.should == 2
	end

	it 'should not remember definer methods' do
		s = Script.new
		s.eval %{
			state :a do
				start do
					reset
					start do
						216
					end
					goto :a
				end
			end
		}
		proc {s.run}.should raise_error
	end

end
