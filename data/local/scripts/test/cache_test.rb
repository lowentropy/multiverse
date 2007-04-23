var :data, "test data"

fun :on_cache_test do
	sync_test
end

fun :sync_test do
	# dump cache before
	puts "initial dump: #{signal?(:dump_cache).inspect}"
	uid = random_uid
	owner = random_uid
	# send data
	reply = send? :sync, host.uid, :cache,
		:uid => uid, :owner => owner,
		:chunks => false, :data_signed => false,
		:data => data
	puts "final dump: #{signal?(:dump_cache).inspect}"
	# make sure response is successful
	if !reply || reply.key != :cache_ack || reply.status.key == :accepted
		puts "sync failed: bad response"
		reply.print if reply
	end
	# make sure it's there now
	found = signal? :uncache, uid
	if data != found
		puts "sync failed: bad data '#{found}'"
		false
	else
		puts "sync succeeded: '#{found}'"
		true
	end
end

state :default do
	fun :start do
		exit
	end
end
