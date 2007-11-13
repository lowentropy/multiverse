@agent = agent 'cache' do
	version 1
	uid '92E4E13D-9DF2-6289-8A0B-FB5E31AEB2C3'
	libs 'scripts/cache/lib.rb'
	code 'scripts/cache/rest.rb', 'scripts/cache/grid.rb'
end

fun(:start) do
	@agent.activate!
	quit
end
