#! /usr/bin/ruby

$: << File.expand_path(File.dirname(__FILE__) + '/..')

require 'includes'
require 'test/sim_net'
require 'test/sim_config'
require 'p2p/host'

include MV::P2P

class PGridSim

	def initialize(options={})
		@num_hosts = options[:num_hosts] || 2
		@num_encounters = options[:num_encounters] || (@num_hosts * 0)
		@num_pubs = options[:num_pubs] || (@num_hosts * 20)
		@num_lookups = options[:num_lookups] || (@num_hosts * 1)
		@data_size = options[:data_size] || 1024
		@never_say_die = true
		@seed = nil
		@hosts = []
		@uids = []
	end

	def run
		populate
		clean
		start
		link
		random_encounters
		publish
		lookups
		shutdown
	end

	def populate
		@num_hosts.times do |i|
			@hosts << Host.new(rand_config(i), SimNet)
			@hosts[-1].load 'ping'
			@hosts[-1].no_local_sends!
			puts "#{@hosts[-1].short}: uid = #{@hosts[-1].uid}"
		end
		@seed = @hosts[0]
	end

	def clean
		@hosts.each do |host|
			host.signal! :clear_cache
		end
	end

	def link
		@hosts[1..-1].each do |host|
			host.signal! :add_seed_host, @seed.info
		end
		@hosts.reverse.each do |host|
			declared_to = host.signal? :declare_self!
			puts "#{host.short}: declared itself to #{declared_to.inspect}"
		end
	end

	def start
		@hosts.each do |host|
			host.start
		end
	end

	def random_encounters
		@num_encounters.times do
			encounter rand_host, rand_host
		end
	end

	def publish
		@num_pubs.times do |i|
			@uids << publish_random(rand_host, i)
		end
	end

	def lookups
		@num_lookups.times do
			lookup rand_host, rand_uid
		end
	end

	def shutdown
		@hosts.reverse.map do |host|
			Thread.new {host.shutdown}
		end.each do |thread|
			thread.join
		end
	end

	def encounter(a, b)
		return if a == b
		#a.signal! :ping, b.info, (reply = [])
		#Thread.pass while reply.empty?
	end
	
	def publish_random(host, i)
		data = rand_data
		uid = MV::Util.random_uid
		pub_to = []
		pub_to = host.signal? :publish!, uid, host.uid, data, false
		puts "##{i+1}: #{uid} published from #{host.address.inspect} to #{pub_to.inspect}"
		uid
	end

	def lookup(host, uid)
	end

	def rand_host
		@hosts[rand(@hosts.size)]
	end

	def rand_uid
		@uids[rand(@uids.size)]
	end

	def rand_data
		data = "0" * @data_size
		@data_size.times do |i|
			data[i] = rand(256)
		end
		data
	end

	def rand_config(id)
		SimConfig.new id
	end

end

if __FILE__ == $0
	options = {}
	ARGV.each do |arg|
		idx = arg.index '='
		next unless idx
		options[arg[0,idx].to_sym] = arg[idx+1..-1]
	end
	PGridSim.new(options).run
end
