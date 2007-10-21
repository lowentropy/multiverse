$: << File.dirname(__FILE__)

require 'rubygems'
require 'log4r'
include Log4r


# The Debug mixin adds debugging support backed by log4r.
module Debug

	# wrap a code block in enter/exit comments
	def debug(name='???', &block)
		if @log && @log.debug? && @debug
			@log.debug "entering #{name}"
			value = yield
			@log.debug "leaving #{name}"
			return value
		else
			return yield
		end
	end

	# for objects that have Configurable mixed in, this configuration
	# option ties the debugging output to the configuration options
	# stored in the configuration key 'log'.
	def config_log(name=self.class.name, options=nil)
		return unless respond_to? :config
		options ||= {}
		@log = Logger.new name
		opts = config_tree('log')
		opts = opts['log'] if opts
		opts ||= (config['log'] = {	'level' => 'debug',
																'trace' => true,
																'file' => nil })
		@log.level = eval((options[:level] || opts['level']).to_s.upcase)
		@log.trace = options[:trace] || opts['trace']
		if opts['file'].nil?
			@log.outputters << StdoutOutputter.new(self.class.name)
		else
			# TODO: test me
			@log.outputters << RollingFileOutputter.new(
				:trunc => false, :maxsize => 1024*1024)
		end
		@log.info "log level: #{@log.level}"
		@log.info "trace: #{@log.trace}"
	end

end
