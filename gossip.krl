ruleset gossip {

	meta {
		name "Gossip"
	}

	global {

		getPeer = function(state) {

		}

		preparedMessage = function(state, subscriber) {

		}

		send = defaction(subscriber, m) {
			send_directive("null", {})
		}

		update = defaction(state) {
			send_directive("null", {})
		}

	}

	rule start_gossiping {
		select when wrangler ruleset_added where rids >< meta:rid
		fired {
			raise gossip event "heartbeat"
		}
	}

	rule gossip {
		select when gossip heartbeat
	}

	rule receive_gossip {
		select when gossip rumor
	}

	rule add_subscription {
		select when gossip sub_request
	}
}