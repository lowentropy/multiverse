@uri_agent = \
agent 'uri' do
	uid 'F78FA286-053A-B231-5C32-979B2AB72599'
	version '0.9.11'
	libs %w(common.rb generic.rb ftp.rb
					http.rb https.rb ldap.rb mailto.rb)
end
