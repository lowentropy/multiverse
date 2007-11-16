describe "URI reputation" do
  it "should record a complaint for a uri" do
    pending "functionality"
		# the really short way
    rep(uid) << N
		# the raw rest way
    some_host["/grid/#{uid}/sammich/complaints"].to_store << N
		# the object-oriented way
    some_object.reputation << a_new_rating
		some_object.reputation.complaints
		# accessing a sammich store directly
		store = some_host["/sammich"].to_store
		store[uid].get # => complaints array for uid
		store[uid].complaints.post N # => adds complaint to uid
		# what actually happens
		rep = some_object.reputation # => Sammich::Person
		rep.refresh # => GET http://.../grid/(uid)/sammich [/complaints]
		rep << N # POST http://.../grid/(uid)/sammich/complaints
  end
end
