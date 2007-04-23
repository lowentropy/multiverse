$: << File.expand_path(File.dirname(__FILE__) + '/..')

require 'p2p/config'
require 'util/uid'

class SimConfig < MV::P2P::HostConfig

	def initialize(id)
		super()
		self.address = id
		self.uid = MV::Util.random_uid
	end

end
