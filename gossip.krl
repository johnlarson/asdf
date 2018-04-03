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
		select when a b
	}

	rule gossip {
		select when a b
	}

	rule receive_gossip {
		select when a b
	}

	rule add_subscription {
		select when a b
	}
}