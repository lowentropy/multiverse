require 'src/ext'

describe "Ext" do
  before :each do
		@sleep_time = 0.5
	end
	
  before :each do
		Thread.critical = false
  end
  
  it 'should allow safe critical in thread' do
		start = Time.now
    lambda {
			Thread.new(@sleep_time) do |time|
				Thread.critical = true
				sleep time
			end.run
		}.should raise_error(ThreadError)
		(Time.now + 0.01 - start).should >= @sleep_time
	end

	it 'should not allow unsafe critical in thread' do
	  lambda {
			Thread.new(@sleep_time) do |time|
				$SAFE = 4
				Thread.critical = true
			end.join
		}.should raise_error(RuntimeError, /^safe.*critical$/)
	end
end