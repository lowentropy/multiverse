a = agent 'foo' do
	uid 'C904AB10-D762-E1E0-0566-E7453D3BEE9F'
	version '2.1.6'
	libs 'scripts/agents.rb'
end

a.activate

fun(:start) { quit }
