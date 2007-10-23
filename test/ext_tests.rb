require 'test/unit'
require 'src/ext'

class ExtTests < Test::Unit::TestCase

	def setup
		@sleep_time = 0.5
	end
	
  def teardown
		Thread.critical = false
  end
    
	def test_thread_should_allow_safe_critical
		start = Time.now
		assert_raise ThreadError do
			Thread.new(@sleep_time) do |time|
				Thread.critical = true
				sleep time
			end.run
		end
		assert (Time.now + 0.01 - start) >= @sleep_time,
			"#{Time.now - start} < #{@sleep_time}"
	end

	def test_thread_should_not_allow_unsafe_critical
		begin
			Thread.new(@sleep_time) do |time|
				$SAFE = 4
				Thread.critical = true
			end.join
		rescue RuntimeError => e
			assert(/^safe.*critical$/ =~ e.message)
		end
	end

end
