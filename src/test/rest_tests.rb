$: << File.expand_path(File.dirname(__FILE__) + '/..')

require 'test/unit'
require 'environment'
require 'server'
require 'host'
require 'rest/rest'

class RestTests < Test::Unit::TestCase

	def setup
		begin
			@server = Server.new :log => {:level => :fatal}, 'port' => 4000
			@host = @server.localhost
		rescue Exception => e
			puts e
			puts e.backtrace
		end
	end

	def teardown
		return unless @server
		@server.shutdown
		@server.join
	rescue Mongrel::StopServer => e
	end

	#%w|foo top_entity top_behavior top_store|.each do |test|
	%w|top_entity|.each do |test|
		define_method "test_#{test}" do
		#	begin
				@server.load :host, {}, "../../scripts/test/rest/#{test}.rb"
				sleep 0.5
				@server.start
				sleep 0.5
				code, response = @server.post @host, '/rest/test'
				puts "BODY: #{response}" if code != 200
				assert_equal 200, code
		#	rescue Exception => e
		#		puts e
		#		puts e.backtrace
		#	end
		end
	end

end
