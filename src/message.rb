$: << File.dirname(__FILE__)

require 'uid'
require 'host'

# A message is like crypto punched through plaque.
class Message

	attr_accessor :command, :host, :url, :params

	def initialize(command, host, url='/', params={})
		@command = command
		@host = host
		@url = url
		@params = params || {}
		@params[:message_id] ||= UID.random
	end

	# a system command doesn't have a host or path
	def self.system(command, params={})
		self.new command, nil, nil, params
	end

	# retrieve a message parameter
	def [](param)
		@params[param]
	end

	# set a message parameter
	def []=(param, value)
		@params[param] = value
	end

	# alias for message[:message_id]
	def id
		self[:message_id]
	end

	# delete a message parameter
	def delete(param)
		@params.delete param
	end

	# string in format of COMMAND protocol://host/path?params
	def to_s
		params = @params.map {|k,v| "#{k}=#{v}"}.join("&")
		"#{command.to_s.upcase} #{proto}#{host}#{url}?#{params}"
	end

	# protocol. http:// for normal message,
	# sys://localhost for system messages.
	def proto
		(host or url) ? "http://" : "sys://localhost"
	end

	# check if this message is a reply, which is the case when the command
	# of the message is :reply and its message_id is the same.
	def replies_to?(message)
		#(@command == :reply) && (self.id == message.id)
		(@command == :reply) && (self[:message_id] == message[:message_id])
	end

	# check for message equivalence
	def ==(other)
		(other != nil) &&
		(other.is_a? self.class) &&
		(@command == other.command) &&
		(@host == other.host) &&
		(@url == other.url) && 
		(@params == other.params)
	end

	# marshal message via some stupid shit bla bla bla (FIXME).
	def marshal
		[@command, @host, @url].map do |obj|
			"#{obj.to_s.size}\n#{obj.to_s}"
		end.join('') + "#{@params.size}\n" +
		@params.map do |k,v|
			str = v.is_a?(Regexp) ? v.source : v.to_s
			"#{k.to_s}\n#{v.class.to_s}\n#{str.size}\n#{str}"
		end.join('')
	end

	# make sense out of stupidity (FIXME)
	def self.unmarshal(text)
		command, text = next_str text
		host, text = next_str text
		host = host.to_host
		url, text = next_str text
		num_params, text = next_line(text)
		num_params = num_params.to_i
		command = command.to_sym
		params = {}
		num_params.times do
			key, text = next_line text
			klass, text = next_line text
			klass = klass.to_sym
			str, text = next_str text
			params[key.to_sym] = case klass
			when :NilClass then nil
			when :Fixnum then str.to_i
			when :Float then str.to_f
			when :Symbol then str.to_sym
			when :Regexp then /#{str}/
			else str; end
		end
		Message.new command, host, url, params
	end

	# parsing helper: get encoded string
	def self.next_str(text)
		size, text = next_line(text)
		size = size.to_i
		[text[0,size],text[size..-1]]
	end

	# parsing helper: get next line
	def self.next_line(text)
		index = text.index("\n") || text.size
		[text[0,index], text[index+1..-1] || '']
	end

end
