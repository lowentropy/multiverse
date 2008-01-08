$:.unshift File.dirname(__FILE__)

require 'rubygems'
require 'net/http'
require 'mongrel'
require 'uri'
require 'ext'

include Net

# The multiverse server. Runs Mongrel.
class Server < Mongrel::HttpHandler

	# set up server
	def initialize(options={})
		@scripts = []
		@routes = []
		@status = {}
		@running = false
		@stopping = false
	end
	
	# immediately abort execution 
	def abort
		@log.fatal "aborted: shutting down"
		stop
		join 0.1
	end

	# start the server; also trap user interrupts.
	def start
		raise 'already started' if @running
		@http = Mongrel::HttpServer.new '0.0.0.0', @port.to_s
		@http.register "/", self
		@thread = @http.run
		trap('INT') { self.abort }
		@running = true
	end

	# shut down the server
	def stop
		@http.stop if @http
		@stopping = true
	end

	# join w/ the server thread
	def join(timeout=nil)
		@thread.join timeout if @thread
		@running = false
		@stopping = false
	end

	# MONGREL: process HTTP request.
	def process(request, response)
		begin
			code, body = handle_http request
		rescue Exception => e
			@log.error e
			code, body = 500, e.message
		end
		response.start(code) do |head,out|
			out.write body
		end
	end

	# issue an HTTP request. this function will block until some
	# respose is received. returns [code, body].
  def send_request(verb, url, body, params, timeout)
		request = create_request(verb, path, body, params)
		uri = URI.parse url
		response = Net::HTTP.start(uri.host, uri.port) do |http|
			http.request request
		end
		[response.code.to_i, response.body]
  end

	# create a properly-constructed request
	def create_request(verb, path, body, params)
		request_class = "HTTP::#{verb.to_s.capitalize}".constantize
		if body and request_class.body?
			request = request_class.new(path + params.url_encode)
			request.body = body
			request.content_type = 'text/plain'
		else
			request = request_class.new path
			request.form_data = params
		end
		request
	end

	# handle a message from the pipe
	def handle_script_request(script, command, params, sync)
		return nil if @stopping
		send command, script, params
	rescue
		@log.error $!
		fail
	end

	# map a url regex to an environment handler id
	def map(script, params)
		@routes[params[:id]] [script, params[:regex]]
		{}
	end

	# update script status
	def status(script, params)
		@status[script] = params[:status]
		{}
	end

	# output script log
	def log(script, params)
		@log.send params[:level], params[:message]
		{}
	end

	# handle an HTTP request; return code, body
	def handle_http(request)
		method, path, body, params = request_info request
		script, id = route path
		if script
			script.handle id, path, body, params, request.params
		else
			{:code => 404, :body => "#{method}: no route to #{url}"}
		end
	end

	# find script and handler id for path
	def route(path)
		@routes.each do |id,pair|
			script, regex = pair
			return [script, id] if regex =~ path
		end
		[nil, nil]
	end

	# get information about the request
	def request_info(request)
		body = read_body(request.body)
		body, params = request_body_params(request, body)
		method = request.params['REQUEST_METHOD'].downcase.to_sym
		path = request.params['REQUEST_PATH']
		[method, path, body, params]
	end

	# read the body from a mongrel request
	def read_body(body)
		if body.kind_of? StringIO
			body.string
		else
			body.read
		end
	end

	# get form params from request
	def request_body_params(request, body)
		body, encoded, params = strip_request_params request, {}
		encoded.split('&').each do |pair|
			key, val = pair.split('=').map {|s| URI.decode(s)}
			params[key] = val
		end
		[body, params]
	end

	# strip request params from request; take them from the body if
	# content-type is url-encoded; otherwise, take them from the
	# request uri. returns [body, encoded_params]
	def strip_request_params(request, body)
		if /encoded/i =~ request.params['CONTENT_TYPE']
			[nil, body || '']
		else
			uri = request.params['REQUEST_URI']
			idx = uri.rindex '?'
			[body, idx ? uri[idx+1..-1] : '']
		end
	end

end
