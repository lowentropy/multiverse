$: << File.expand_path(File.dirname(__FILE__) + '/..')

require 'includes'


module MV::Util

	class Logger

		def initialize(host, name, stamp=true, format=nil)
			@format = format || "%Y%m%d [%Z] %H:%M.%S"
			@host, @name, @stamp = host, name, stamp
			@file = File.open host.file(:log, name.to_s), 'w'
			@buffer = [].taint
			@puts_buf = [].taint
		end

		def log(msg, level=:info)
			if $SAFE > 0
				@buffer << [msg, level]
			else
				level = "% 4s" % [level]
				log = "#{level} : #{stamp+msg.to_s}"
				if @file
					@file.puts log
					@file.flush
				end
				if debug?
					$stdout.puts log
					$stdout.flush
				end
			end
		end

		def debug?
			@host.debug?
		end

		def dbg(msg)
			log msg, :dbg if debug?
		end

		def flush
			return unless $SAFE == 0
			until @buffer.empty?
				to_log = @buffer.shift
				if to_log[0].respond_to? :backtrace
					log_err *to_log
				else
					log *to_log
				end
			end
			until @puts_buf.empty?
				$stdout.puts @puts_buf.shift
			end
		end

		def stamp
			return '' unless @stamp
			Time.now.strftime(@format) + ' : '
		end

		def close
			@file.close
			@file = nil
		end

		def log_err(err, level=:err)
			if $SAFE > 0
				@buffer << [err, level]
			else
				fmt = format_err err
				log fmt, level
			end
		end

		def safe(level=:err, &block)
			begin
				yield
			rescue
				log_err $!, level
				nil
			end
		end

		def puts(str)
			if $SAFE > 0
				@puts_buf << str
			else
				$stdout.puts str
			end
		end

		def format_err(err)
			"#{err.class}: #{err}\n" + err.backtrace.map {|tr| "\t#{tr}"}.join("\n")
		end

	end

end
