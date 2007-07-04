$: << File.dirname(__FILE__)

require 'uid'

class Message

	attr_accessor :command, :host, :url

	def initialize(command, host='localhost', url='/', params={})
		@command = command
		@host = host
		@url = url
		@params = params || {}
		@params[:message_id] ||= UID.random
	end

	def [](param)
		@params[param]
	end

	def []=(param, value)
		@params[param] = value
	end

	def delete(param)
		@params.delete param
	end

	def to_s
		params = @params.map {|k,v| "#{k}=#{v}"}.join("&")
		"#{command.to_s.upcase} #{host}#{url}?#{params}"
	end

	def replies_to?(message)
		(@command == :reply) && (self[:message_id] == message[:message_id])
	end

	def marshal
		[@command, @host, @url].map do |obj|
			"#{obj.to_s.size}\n#{obj.to_s}"
		end.join('') + "#{@params.size}\n" +
		@params.map do |k,v|
			"#{k.to_s}\n#{v.class.to_s}\n" +
			"#{v.to_s.size}\n#{v.to_s}"
		end.join('')
	end

	def self.unmarshal(text)
		command, text = next_str text
		host, text = next_str text
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
			when :Fixnum then str.to_i
			when :Float then str.to_f
			when :Symbol then str.to_sym
			else str; end
		end
		Message.new command, host, url, params
	end

	def self.next_str(text)
		size, text = next_line(text)
		size = size.to_i
		[text[0,size],text[size..-1]]
	end

	def self.next_line(text)
		index = text.index "\n"
		[text[0,index], text[index+1..-1]]
	end

end
