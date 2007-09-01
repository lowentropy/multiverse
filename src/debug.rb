$: << File.dirname(__FILE__)

require 'rubygems'
require 'log4r'
include Log4r

module Debug

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

	def config_log(options=nil)
		return unless respond_to? :config
		options ||= {}
		@log = Logger.new self.class.name
		opts = config_tree('log')
		opts = opts['log'] if opts
		opts ||= (config['log'] = {'level' => 'debug', 'trace' => true, 'file' => nil})
		@log.level = eval((options[:level] || opts['level']).to_s.upcase)
		@log.trace = options[:trace] || opts['trace']
		if opts['file'].nil?
			@log.outputters << StdoutOutputter.new(self.class.name)
		else
			# FIXME
			@log.outputters << RollingFileOutputter.new(:trunc => false, :maxsize => 1024*1024)
		end
		@log.info "started with level = #{@log.level}, trace = #{@log.trace}"
	end

end
