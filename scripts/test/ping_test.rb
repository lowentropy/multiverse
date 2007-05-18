req File.expand_path(File.dirname(__FILE__) + '/../host/ping.rb')

fun :test_ping do
	assert_OK do
		host.perform 'echo', :text => 'foo'
	end
end
