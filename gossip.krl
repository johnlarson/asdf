ruleset gossip {

	meta {
		name "Gossip"
	}

	global {

		__testing = {
			"queries": [
				{
					"name": "getPeer",
					"args": ["state"]
				},
				{
					"name": "preparedMessage",
					"args": ["state", "subscriber"]
				}
			],
			"events": [
				{
					"domain": "gossip",
					"type": "heartbeat",
					"args": []
				},
				{
					"domain": "gossip",
					"type": "rumor",
					"args": []
				},
				{
					"domain": "gossip",
					"type": "known",
					"args": []
				},
				{
					"domain": "gossip",
					"type": "sub_request",
					"args": []
				}
			]
		}

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

	rule receive_rumor {
		select when gossip rumor
	}

	rule receive_known {
		select when gossip known
	}

	rule add_subscription {
		select when gossip add_subscription
	}

	rule record_own_temp {
		select when wovyn new_temperature_reading
	}
}