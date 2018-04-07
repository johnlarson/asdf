ruleset gossip {

	meta {
		name "Gossip"
		shares __testing, getPeer
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
		RUMOR_FACTOR = 3
		KNOWN_FACTOR = 2

		getPeer = function() {
			mine = ent:seen{meta:picoId};
			scores = ent:seen.map(function(v, k) {
				getNeedScore(v)
			});
			total = 0;
			bounds = scores.keys().reduce(function(a, b) {
				addable = {
					"id": k,
					"min": a{"total"}
				};
				a = a.put("total", a{"total"} + scores{b});
				addable.put("max", a{"total"} - 1);
			}, {"total": 0});
			rand = random:integer(bounds{"total"} - 1);
			bounds = bounds.delete(["total"]);
			bounds.filter(function(v, k) {
				rand >= v{"min"} && rand <= v{"max"}
			}).values(){[0, "id"]}
		}

		getNeedScore = function(seen) {
			seen.keys().reduce(function(a, b) {
				a + getNeedScoreSingle(seen, b)
			}, 0)
		}

		getNeedScoreSingle = function(seen, key) {
			diff = ent:seen{[meta:picoId, key]} - seen{key};
			diff < 0 => -diff * KNOWN_FACTOR | diff * RUMOR_FACTOR
		}

		getNextSequenceNumber = function() {
			id = meta:picoId;
			ent:seen{[id, id]} != null => maxSelfKnown(id) + 1 | 0
		}

		maxSelfKnown = function(id) {
			mine = ent:rumors{meta:picoId};
			idx = mine.index(null);
			idx == -1 => mine.length() - 1 | idx - 1
		}

		preparedMessage = function(subscriber) {

		}

		send = defaction(subscriber, m) {
			send_directive("null", {})
		}

	}

	rule start_gossiping {
		select when wrangler ruleset_added where rids >< meta:rid
		fired {
			raise gossip event "heartbeat" attributes {}
		}
	}

	rule gossip {
		select when gossip heartbeat
		pre {
			subscriber = getPeer().klog("PEER")
			m = preparedMessage(peer)
		}
		send(subscriber, m)
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
			ent:seen := ent:seen.defaultsTo({});
			ent:seen{me} := ent:seen{me}.defaultsTo({});
			ent:seen{[me, id]} := maxSelfKnown(id)
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