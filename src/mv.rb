module MV

	def self.init
		@outbox = []
		@inbox = {}
		@routes = {}
		@outbox_mutex = Mutex.new
		@inbox_mutex = Mutex.new
	end

	def self.send_out(id, command, params)
		@outbox_mutex.synchronize do
			@outbox << [id, command, params]
		end
	end

	def self.read_in(id, params)
		@inbox_mutex.synchronize do
			@inbox[id] = params
		end
	end

	def self.sync(command, params={})
		wait_for async(command, params)
	end

	def self.async(command, params={})
		id = UID.random
		send_out id, command, params
		id
	end

	def self.wait_for(id)
		Thread.pass until @inbox[id]
		@inbox.delete id
	end

	%w(get put post delete).each do |verb|
		self.define_method verb do |url,borp,*rest|
			body, params = if borp.kind_of? Hash
				'', borp
			else
				borp, {}
			end
			timeout = rest.shift # TODO: default timeout
			sync :http,
				{	:verb => verb.to_sym,
					:body => body,
					:params => params,
					:timeout => timeout }
		end
	end

	def log(level, message)
		async :log, {:level => level, :message => message}
	end

	def map(regex, &block)
		@routes[id = UID.random] = block
		async :map, {:id => id, :regex => regex}
		id
	end

	def unmap(id)
		@routes.delete id
		async :unmap, {:id => id}
	end

end
