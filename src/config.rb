$: << File.expand_path(File.dirname(__FILE__))

require 'yaml'

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
