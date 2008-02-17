class << self
	include REST
end

class TestEntity; end

entity(/foo/, TestEntity) do
	attributes :foo, :bar, :baz
end.serve

MV.map(/^\/rest\/test/, proc do
	MV.log :info, "sending request to /foo"
	begin
		body = '/foo'.to_entity.get
		MV.log :info, "request to /foo suceeded with #{body.inspect}"
		reply :body => body
	rescue RestError => e
		MV.log :error, "request to /foo failed with #{e.message}"
		reply :code => e.code, :body => e.body
	end
end)
