use! 'rest'
include REST

fun :start do
	quit
end

class TestEntity; end

entity(/foo/, TestEntity) do
	attributes :foo, :bar, :baz
end

map :rest do
  fun :test do
    log "sending request to /foo"
    begin
      body = '/foo'.to_entity.get
      log "request to /foo suceeded with #{body.inspect}"
      reply :body => body
    rescue RestError => e
      log "request to /foo failed with #{e.message}"
      reply :code => e.code, :body => e.body
    end
  end
end

# TODO: this should be implicit...
map_rest
