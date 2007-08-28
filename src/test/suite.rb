$: << File.dirname(__FILE__)

require 'test/unit/ui/console/testrunner'
require 'test/unit/testsuite'
require 'message_tests'
require 'sandbox_tests'
require 'environment_tests'
require 'untrace_tests'
require 'script_tests'
require 'instance_exec_tests'
require 'config_tests'

class MVTestSuite
	def self.suite
		suite = Test::Unit::TestSuite.new 'Multiverse Tests'
		suite << MessageTests.suite
		suite << SandboxTests.suite
		suite << EnvironmentTests.suite
		suite << UntraceTests.suite
#		suite << ScriptTests.suite
		suite << InstanceExecTests.suite
		suite << ConfigTests.suite
		return suite
	end
end

if __FILE__ == $0
	Test::Unit::UI::Console::TestRunner.run MVTestSuite
end
