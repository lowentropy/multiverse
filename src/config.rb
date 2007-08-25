$: << File.expand_path(File.dirname(__FILE__))

require 'yaml'

module Configurable

	@@base = '.'

	def self.base=(base)
		@@base = base
	end

	def config(all=false)
		raise "no configuration found" unless @config || @config_root
		config = @config || @config_root.config(true)
		if @section and not all
			@section.each do |section|
				config = config[section]
			end
		end
		config
	end
	
	def config_file(file=nil, section=nil)
		file ||= self.class.to_s.downcase + '.config'
		@config = Configuration.load "#{@@base}/#{file}"
		@section = case section
			when Array then section
			when nil then []
			else [section]
		end
	end

	def config_root(object)
		raise "invalid config root" unless object.respond_to? :config
		@config = nil
		@config_root = object
	end

	def config_save
		config(true).save!
	end

end

class Configuration < Hash

	attr_accessor :filename

	def initialize(hash)
		merge! hash
	end

	def to_yaml
		super
	end

	def self.load(filename)
		config = YAML.load(File.open(filename))
		config.filename = filename
		config
	end

	def self.parse(yaml)
		YAML.parse(yaml).transform
	end

	def save!
		raise "no file name set" unless @filename
		File.open(@filename, 'w') do |file|
			file.write to_yaml
		end
	end

end
