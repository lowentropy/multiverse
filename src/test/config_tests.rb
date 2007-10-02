$: << File.expand_path(File.dirname(__FILE__) + '/..')

require 'test/unit'
require 'config'


class Array
	def inject_with_index(value=0, &block)
		each_with_index do |x,i|
			value = yield value, x, i
		end
		value
	end
	def without(i)
		self[0,i] + self[i+1..-1]
	end
	def permute
		return self if empty?
		return [self] if size == 1
		inject_with_index([]) do |a,x,i|
			a + without(i).permute.map {|p| [x,*p]}
		end
	end
end

class ConfigTests < Test::Unit::TestCase

	class HasConfig
		include Configurable
	end

	def setup
		Configurable.base = '.'
		@hash = {1=>2, :a=>:b, 'c'=>'d'}
		@yaml = <<-END
--- !map:Configuration 
1: 2
c: d
:a: :b
		END
		class << @yaml
			def permute
				lines = split /\r?\n/
				lines[1..-1].permute.map {|p| [lines[0], *p].join("\n")}
			end
		end
	end

	def test_initialize
		assert_equal @hash, Configuration.new(@hash)
	end

	def test_load_host_config
		assert_nothing_raised do
			Configuration.load '../../config/host.config'
		end
	end

	def test_to_yaml
		actual = Configuration.new(@hash).to_yaml.strip
		assert @yaml.permute.include?(actual)
	end

	def test_parse_yaml
		conf = Configuration.new(@hash)
		assert_equal conf, Configuration.parse(conf.to_yaml)
	end

	def test_load
		File.open('temp','w') do |file|
			file.write @yaml
		end
		assert_equal Configuration.new(@hash), Configuration.load('temp')
	end

	def test_save_ok
		File.open('temp','w') do |file|
			file.write @yaml
		end
		config = Configuration.load('temp')
		config.save!
		assert @yaml.permute.include?(File.read('temp').strip)
	end

	def test_save_new_file
		config = Configuration.new(@hash)
		config.filename = 'temp'
		config.save!
		assert @yaml.permute.include?(File.read('temp').strip)
	end

	def test_save_nofile
		assert_raises RuntimeError do
			Configuration.new(@hash).save!
		end
	end

	def test_configurable
		h = HasConfig.new
		h.config_file 'temp'
		assert_equal @hash, h.config
	end

	def test_part_configurable
		[:a, 1, 'c'].each do |key|
			h = HasConfig.new
			h.config_file 'temp', key
			assert_equal @hash[key], h.config
		end
	end

	def test_config_root
		h1 = HasConfig.new
		h1.config_file 'temp', :a
		h2 = HasConfig.new
		h2.config_root h1
		assert_equal @hash[:a], h1.config
		assert_equal @hash, h2.config
	end

	def test_config_base
		Configurable.base = File.expand_path(File.dirname(__FILE__) + '/../../config')
		h = HasConfig.new
		h.config_file 'host.config', 'host'
		assert_not_nil h.config
		assert_instance_of Array, h.config['scripts']
		assert_instance_of Hash, h.config['io']
	end

	def test_save_config
		h = HasConfig.new
		h.config_file 'temp'
		h.config[:a] = 'foo'
		h.config_save
		assert_equal @hash.merge(:a => 'foo'), Configuration.load('temp')
	end

	def test_save_config_from_sub
		h = HasConfig.new
		sub = HasConfig.new
		sub.config_root h
		h.config_file 'temp'
		h.config[:a] = 'foo'
		sub.config_save
		assert_equal @hash.merge(:a => 'foo'), Configuration.load('temp')
	end

end
