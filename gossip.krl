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

		}

		update = defaction(state) {
		
		}

	}

	rule start_gossiping {
		select when a b
	}

	rule gossip {
		select when a b
	}
}