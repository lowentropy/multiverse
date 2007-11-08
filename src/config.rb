require 'yaml'

# Extensions to hash to perform recursive merging.
class Hash
	# create a new hash which is recursively merged with the
	# given hash by calling merge_recursive on hash values
	# that are themselves hashes
	def merge_recursive(other)
		merge(other) do |key,old,new|
			new.kind_of?(Hash) ? old.merge_recursive(new) : new
		end
	end
	# destructive in-place version of merge_recursive
	def merge_recursive!(other)
		merge!(other) do |key,old,new|
			new.kind_of?(Hash) ? old.merge_recursive(new) : new
		end
	end
end

# A mixin that adds persisten YAML configuration capability
# to any object. Configuration can be done using an entire
# YAML file or a portion of that file.
module Configurable

	@@base = '.'

	# sets the base configuration directory
	def self.base=(base)
		@@base = base
	end

	# override configuration with a hash of options
	# (for example, as provided by the user)
	def config_options(options={})
		config.merge_recursive! options
	end

	# return the configuration subtree which contains the given key
	def config_tree(key, root=config(true), sec=@section.clone)
		return root if root.has_key? key
		return nil if sec.empty?
		config_tree(key, root[sec.shift], sec)
	end

	# return the configuration hash pointed to by the object
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

	# set default configuration values; doesn't overwrite
	# those values if they exist already.
	def config_default(defaults={})
		config = self.config
		defaults.each do |key,value|
			config[key] = value unless config.has_key?(key)
		end
	end
	
	# set the configuration file to use
	def config_file(file=nil, section=nil)
		file ||= self.class.to_s.downcase + '.config'
		@config = Configuration.load "#{@@base}/#{file}"
		@section = case section
			when Array then section
			when nil then []
			else [section]
		end
	end

	# set the configuration to be a pointer to some other Configurable
	def config_root(object)
		raise "invalid config root" unless object.respond_to? :config
		@config = nil
		@config_root = object
	end

	# store changes to the configuration
	def config_save
		config(true).save!
	end

end


# Configuration is an extended hash that serializes to YAML.
class Configuration < Hash

	# the file in which the configuration is loaded/stored
	attr_accessor :filename

	# initialize to the given hash
	def initialize(hash)
		merge! hash
	end

	# convert to YAML (uses builtin Hash#to_yaml)
	def to_yaml
		super
	end

	# load a configuration from a file
	def self.load(filename)
		config = YAML.load(File.open(filename))
		config.filename = filename
		config
	end

	# load a configuration from a YAML string
	def self.parse(yaml)
		YAML.parse(yaml).transform
	end

	# save changes to the configuration. requires that the
	# configuration has some associated filename.
	def save!
		raise "no file name set" unless @filename
		File.open(@filename, 'w') do |file|
			file.write to_yaml
		end
	end

end
