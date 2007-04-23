$: << File.expand_path(File.dirname(__FILE__) + '/..')

require 'includes'


module MV::Util::SafeErrors

	def safe(*methods)
		methods.each do |method|
			old = "unsafe_#{method}".to_sym
			self.send :alias_method, old, method
			self.send :eval, <<-END
				def #{method}(*args, &block)
					@log.safe do
						#{old} *args, &block
					end
				end
			END
		end
	end

end
