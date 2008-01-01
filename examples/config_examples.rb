require 'rubygems'
require 'spec'
require 'src/config'
require 'src/ext'

describe "Configuration" do
  before :each do
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

  after :each do
    if File::exist?('temp')
      File::delete('temp') 
    end
  end
  
  it 'should initialize to hash' do
    Configuration.new(@hash).should == @hash
	end
  
  it 'should load host configuration' do
		lambda { Configuration.load 'config/host.config' }.should_not raise_error
	end
	
  it 'should serialize to yaml' do
		actual = Configuration.new(@hash).to_yaml.strip
		
    @yaml.permute.include?(actual).should be_true
	end
  
  it 'should parse from yaml' do
		conf = Configuration.new(@hash)
		
    Configuration.parse(conf.to_yaml).should == conf
	end
	
  it 'should save new file' do
		config = Configuration.new(@hash)
		config.filename = 'temp'
		config.save!
		
    @yaml.permute.include?(File.read('temp').strip).should be_true
	end
	
  it 'should not save without a filename' do
		lambda { Configuration.new(@hash).save! }.should raise_error(RuntimeError)
	end
	
  
  it 'should config base' do
		Configurable.base = File.expand_path(File.dirname(__FILE__) + '/../config')
		h = HasConfig.new
		h.config_file 'host.config', 'host'
		
		h.config.should_not be_nil
		h.config['scripts'].should be_instance_of(Array)
		h.config['io'].should be_instance_of(Hash)
	end
  
  it 'should load yaml from file' do
		File.open('temp','w') do |file|
			file.write @yaml
		end
		
		Configuration.load('temp').should == Configuration.new(@hash)
	end
  
  it 'should save ok' do
		File.open('temp','w') do |file|
			file.write @yaml
		end
		config = Configuration.load('temp')
		config.save!
		
    @yaml.permute.include?(File.read('temp').strip).should be_true
	end
  
  it 'should find config of configurable object' do
    File.open('temp','w') do |file|
      file.write @yaml
    end
  
		h = HasConfig.new
		h.config_file 'temp'
		
    h.config.should == @hash
	end
  
  it 'should part configurable' do
    File.open('temp','w') do |file|
      file.write @yaml
    end
  
		[:a, 1, 'c'].each do |key|
			h = HasConfig.new
			h.config_file 'temp', key
			
      h.config.should == @hash[key]
		end
	end
  
  it 'should config root' do
    File.open('temp','w') do |file|
      file.write @yaml
    end
	  
		h1 = HasConfig.new
		h1.config_file 'temp', :a
		h2 = HasConfig.new
		h2.config_root h1
		
    h1.config.should == @hash[:a]
		h2.config.should == @hash
	end
	
  it 'should save configuration' do
    File.open('temp','w') do |file|
      file.write @yaml
    end
  
		h = HasConfig.new
		h.config_file 'temp'
		h.config[:a] = 'foo'
		h.config_save
		
		Configuration.load('temp').should == @hash.merge(:a => 'foo')
	end
	
  it "should save configuration from sub" do
    File.open('temp','w') do |file|
      file.write @yaml
    end

		h = HasConfig.new
		sub = HasConfig.new
		sub.config_root h
		h.config_file 'temp'
		h.config[:a] = 'foo'
		sub.config_save
    
    Configuration.load('temp').should == @hash.merge(:a => 'foo')
  end
end

class HasConfig
	include Configurable
end
