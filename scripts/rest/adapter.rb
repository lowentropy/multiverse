module REST

	class Adapter
	  attr_reader :uri
		def initialize(url)
			@uri = URI.parse(url)
		end
		def get(params={})
			hash = MV.get @uri.to_s, '', params
			code, body = hash[:code], hash[:body]
			raise RestError.new(code, body) if code != 200
			YAML.load body
		end
		def put(body='', params={})
			hash = MV.put @uri.to_s, body, params
			code, body = hash[:code], hash[:body]
			raise RestError.new(code, body) if code != 200
		end
		alias :set :put
		def post(body='', params={})
			hash = MV.post @uri.to_s, body, params
			code, body = hash[:code], hash[:body]
			raise RestError.new(code, body) if code != 200
			YAML.load body
		end
		def delete
			hash = MV.delete @uri.to_s, body, {}
			code, body = hash[:code], hash[:body]
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
