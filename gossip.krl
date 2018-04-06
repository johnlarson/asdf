ruleset gossip {

	meta {
		name "Gossip"
		shares __testing
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
				},
				{
					"name": "maxSelfKnown",
					"args": ["id"]
				}
			],
			"events": [
				{
					"domain": "gossip",
					"type": "heartbeat",
					"attrs": []
				},
				{
					"domain": "gossip",
					"type": "rumor",
					"attrs": [
						"MessageID",
						"SensorID",
						"Temperature",
						"Timestamp"
					]
				},
				{
					"domain": "gossip",
					"type": "add_subscription",
					"attrs": ["wellKnown_Tx", "Tx_host"]
				}
			]
		}

		INTERVAL = 1000

		getPeer = function(state) {

		}

		getNextSequenceNumber = function() {
			id = meta:picoId;
			ent:known{[id, id]}.klog("EXISTS?") != null => maxSelfKnown(id) + 1 | 0
		}

		maxSelfKnown = function(id) {
			mine = ent:rumors{meta:picoId};
			idx = mine.index(null);
			idx == -1 => mine.length() - 1 | idx - 1
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
		fired {
			
		}
	}

	rule set_gossip_timeout {
		select when gossip heartbeat
		fired {
			schedule gossip event "heartbeat" at time:add(time:now(), {"ms": INTERVAL})
		}
	}

	rule receive_rumor {
		select when gossip rumor
		pre {
			mid = event:attr("MessageID")
			parts = mid.split(":")
			id = parts[0]
			seq = parts[1]
			me = meta:picoId
		}
		fired {
			ent:rumors := ent:rumors.defaultsTo({});
			ent:rumors{id} := ent:rumors{id}.defaultsTo([]);
			ent:rumors{[id, seq]} := event:attrs;
			ent:known := ent:known.defaultsTo({});
			ent:known{me} := ent:known{me}.defaultsTo({});
			ent:known{[me, id]} := maxSelfKnown(id)
		}
	}

	rule receive_seen {
		select when gossip seen

	}

	rule add_subscription {
		select when gossip add_subscription
		fired {
			raise wrangler event "subscription"
				attributes {
					"channel_type": "subscription",
					"Tx_host": event:attr("Tx_host"),
					"wellKnown_Tx": event:attr("wellKnown_Tx"),
					"Rx_role": "node",
					"Tx_role": "node"
				}
		}
	}

	rule record_own_temp {
		select when wovyn new_temperature_reading
		pre {
			id = meta:picoId
			seq = getNextSequenceNumber()
		}
		fired {
			raise gossip event "rumor"
				attributes {
					"MessageID": <<#{id}:#{seq}>>,
					"SensorID": id,
					"Temperature": event:attr("temperature"),
					"Timestamp": event:attr("timestamp")
				}
		}
	}

}