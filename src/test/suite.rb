$: << File.dirname(__FILE__)

require 'test/unit/ui/console/testrunner'
require 'test/unit/testsuite'
require 'message_tests'

class MVTestSuite
	def self.suite
		suite = Test::Unit::TestSuite.new 'Multiverse Tests'
		suite << MessageTests.suite
		return suite
	end
end

if __FILE__ == $0
	Test::Unit::UI::Console::TestRunner.run MVTestSuite
end
