module REST

	class Adapter
	  attr_reader :uri
		def initialize(url)
			@uri = URI.parse(url)
		end
		def get(params={})
			reply = MV.get :url => @uri.to_s, :params => params
			raise RestError.new(reply) if reply.code != 200
			YAML.load reply.body
		end
		def put(body='', params={})
			reply = MV.put :url => @uri.to_s, :body => body, :params => params
			raise RestError.new(reply) if reply.code != 200
			nil
		end
		alias :set :put
		def post(body='', params={})
			reply = MV.post :url => @uri.to_s, :body => body, :params => params
			raise RestError.new(reply) if reply.code != 200
			YAML.load reply.body
		end
		def delete
			reply = MV.delete :url => @uri.to_s
			raise RestError.new(reply) if reply.code != 200
			nil
		end
		# a no-argument missing method call should refer
		# to some kind of sub-instance
		def method_missing(id, *args)
			return super if args.any?
			return "#{uri}/#{id.id2name}".to_rest
		end
	end
end
