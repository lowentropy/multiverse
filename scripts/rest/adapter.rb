module REST

	class Adapter
	  attr_reader :uri
		def initialize(url)
			@uri = URI.parse(url)
		end
	  def env
	    $env
    end
		def get(params={})
			code, body = $env.get @uri.to_s, '', params
			raise RestError.new(code, body) if code != 200
			YAML.load body
		end
		def put(body='', params={})
			code, body = $env.put @uri.to_s, body, params
			raise RestError.new(code, body) if code != 200
		end
		alias :set :put
		def post(body='', params={})
			code, body = $env.post @uri.to_s, body, params
			raise RestError.new(code, body) if code != 200
			YAML.load body
		end
		def delete
			code, body = $env.delete @uri.to_s, '', {}
			raise RestError.new(code, body) if code != 200
		end
		# a no-argument missing method call should refer
		# to some kind of sub-instance
		def method_missing(id, *args)
			return super if args.any?
			return "#{uri}/#{id.id2name}".to_rest
		end
	end
end
