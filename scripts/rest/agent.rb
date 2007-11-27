agent 'rest' do
	uid '01F50A65-1AF7-AEB2-6850-C4324D9E446D'
	version '0.0.0'
	libs *(%w(adapter pattern store
					entity behavior rest
	 			).map {|file| "scripts/rest/#{file}.rb" })
end
