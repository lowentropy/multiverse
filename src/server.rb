$:.unshift File.dirname(__FILE__)

require 'rubygems'
require 'ruby2ruby'
require 'net/http'
require 'mongrel'
require 'script'
require 'log4r'
require 'uri'
require 'ext'
require 'mv'

include Net

# The multiverse server. Runs Mongrel.
class Server < Mongrel::HttpHandler

	# set up server
	def initialize(options={})
		@routes = {}
		@threads = []
		@scripts = []
		@running = false
		@stopping = false
		@port = 4000
		@log = Log4r::Logger.new 'server'
		@log.outputters << Log4r::StdoutOutputter.new('MV')
		$thread = MV::ThreadLocal.new
	end

	# load scripts into their own sandboxes
	def load(*scripts)
		raise "must start server before loading" unless running?
		raise "can't load scripts while stopping" if stopping?
		scripts.each do |name|
			script = Script.new name
			script.eval File.read(name)
			run(script)
		end
	end

	# run a script
	def run(script)
		raise "must start server before runnign script" unless running?
		raise "can't run script while stopping" if stopping?
		@scripts << script
		@threads << [Thread.new(script, exc=[]) do
			$thread[:server] = self
			begin
				script.run
				@scripts.delete script
			rescue Exception => e
				script.failed!
				exc << e
			end
		end, exc]
		Thread.pass until script.running? or script.failed?
	end
	
	# immediately abort execution 
	def abort
		raise "not running" unless running?
		stop unless stopping?
		join 0
	end
	
	# is the server running?
	def running?
		@running
	end

	# is the server in the process of stopping?
	def stopping?
		@stopping
	end

	# start the server; also trap user interrupts.
	def start
		raise 'already running' if running?
		@http = Mongrel::HttpServer.new '0.0.0.0', @port.to_s
		@http.register "/", self
		@thread = @http.run
		@running = true
		trap('INT') { self.abort }
	end

	# shut down the server
	def stop
		return unless running?
		raise 'already stopping' if stopping?
		@stopping = true
		@http.stop if @http
		@scripts.each do |script|
			script.stop
		end
	end

	# join a thread with a timeout. if it does time out, kill it.
	def join_kill(thread, timeout)
		thread.join timeout
		thread.kill!
	end

	# join w/ the server thread. returns an array of errors
	# which occured in the separate scripts.
	def join(timeout=nil)
		join_kill @thread, timeout if @thread
		errors = []
		until @threads.empty?
			thread, exc = @threads.shift
			join_kill thread, timeout
			errors << exc[0] if exc.any?
		end
		@running = false
		@stopping = false
		errors
	end

	# MONGREL: process HTTP request.
	def process(request, response)
		hash = begin
			handle_http request
		rescue Exception => e
			{:code => 500, :body => [e.message, *e.backtrace].join("\n")}
		end
		write_http_response(response, hash)
	end

	# send HTTP response from mongrel
	def write_http_response(response, hash)
		code = hash.delete :code
		body = hash.delete :body
		response.start(code) do |head,out|
			hash.each {|k,v| head[k] = v}
			out.write body
		end
	end

	# issue an HTTP request. this function will block until some
	# respose is received. returns [code, body, headers].
  def send_request(verb, url, body, type, params, timeout)
		uri = URI.parse url
		request = create_request(verb, url, body, type, params)
		# TODO: put a timeout on this
		response = Net::HTTP.start(uri.host, uri.port) do |http|
			http.request request
		end
		[response.code, response.body, response.to_hash]
  end

	# create a properly-constructed request
	def create_request(verb, path, body, type, params)
		request_class = "HTTP::#{verb.to_s.capitalize}".constantize
		if body and request_class.body?
			request = request_class.new(path + params.url_encode)
			request.body = body
			request.content_type = type
		else
			request = request_class.new path
			request.form_data = params
		end
		request
	end

	# map a url regex to a script handler id
	def map(script, id, regex)
		@routes[id] = [script, regex]
	end

	# output script log
	def log(script, level, message)
		name = script ? script.name : 'server'
		name = name[-10..-1] if name.size > 10
		message = "[%10s] %s" % [name, message]
		@log.send level, message
	end

	# load some text into a script
	def req(script, *files)
		files.each do |file|
			script.eval File.read(file)
		end
	end

	# handle an HTTP request; return code, body
	def handle_http(request)
		method, path, body, params = request_info request
		script, id = route path
		if script
			$thread[:server] = self
			script.handle id, body, params, request.params
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
		#method = request['request_method'].downcase.to_sym
		method = request.params['REQUEST_METHOD'].downcase.to_sym
		#path = request['request_path']
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
		params = {}
		body, encoded = strip_request_params(request, body)
		(encoded || '').split('&').each do |pair|
			key, val = pair.split('=').map {|s| URI.decode(s)}
			params[key] = val
		end
		[body, params]
	end

	# strip request params from request; take them from the body if
	# content-type is url-encoded; otherwise, take them from the
	# request uri. returns [body, encoded_params]
	def strip_request_params(request, body)
		if /encoded/i =~ request.params['HTTP_CONTENT_TYPE']
			[nil, body || '']
		else
			uri = request.params['REQUEST_URI']
			idx = uri.index '?'
			query = idx ? uri[idx+1..-1] : ''
			[body, query]
		end
	end

end
