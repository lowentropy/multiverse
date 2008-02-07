@rest_agent = \

agent 'rest' do
	uid '01F50A65-1AF7-AEB2-6850-C4324D9E446D'
	version '0.0.0'
	libs *(%w(adapter.rb pattern.rb store.rb
						entity.rb behavior.rb rest.rb))
end
