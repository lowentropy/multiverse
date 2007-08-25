$: << File.expand_path(File.dirname(__FILE__) + '/..')

require 'test/unit'
require 'config'


class ConfigTests < Test::Unit::TestCase

	def setup
		@hash = {1=>2, :a=>:b, 'c'=>'d'}
		@yaml = <<-END
--- !map:Configuration 
1: 2
c: d
:a: :b
		END
	end

	def test_initialize
		assert_equal @hash, Configuration.new(@hash)
	end

	def test_to_yaml
		assert_equal(@yaml, Configuration.new(@hash).to_yaml)
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
		assert_equal @yaml, File.read('temp')
	end

	def test_save_new_file
		config = Configuration.new(@hash)
		config.filename = 'temp'
		config.save!
		assert_equal @yaml, File.read('temp')
	end

	def test_save_nofile
		assert_raises RuntimeError do
			Configuration.new(@hash).save!
		end
	end

end
