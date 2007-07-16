$: << File.dirname(__FILE__)

module Debug

	def debug(name='???', &block)
		return yield unless @debug
		$stdout.write("SRV DBG: #{name}...")
		$stdout.flush
		value = yield
		$stdout.write(" done.\n")
		$stdout.flush
		value
	end

end
