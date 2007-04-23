require 'net/server'

class SimNet < MV::Net::Server

	@@hosts = {}
	
	def shutdown; end
	def join; end
	def thread; end

	def start(*args)
		start_handler
	end

	def owned_by(host)
		@@hosts[host.address] = host
		self
	end

	def transmit_async(address, msg)
		raise "no local sends in sim" if address == :local
		from = @mv_host.info.address.inspect
		#puts "#{from}: transmitting #{msg.key} to #{address.inspect}"
		@@hosts[address].net.send :receive_chunk, msg.marshal
	end

end
