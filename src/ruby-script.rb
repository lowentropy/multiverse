#! /usr/bin/ruby

$: << File.dirname(__FILE__)

require 'environment'

env = Environment.new
trap 'INT' do
	env.shutdown!
	env.join 0.1
end
env.run
env.join
