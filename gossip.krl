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
			chooseRandomly(ent:seen, "key", function(v, k) {
				getMyNeedScore(v);
			})
		}

		getMyNeedScore = function(seen) {
			mySeen = ent:seen{meta:picoId};
			rumorScore = getNeedScore(mySeen, seen);
			seenScore = getNeedScore(seen, mySeen);
			RUMOR_FACTOR * rumorScore + SEEN_FACTOR * seenScore
		}

		getNeedScore = function(seen1, seen2) {
			seen1.keys().reduce(function(a, b) {
				a + getNeedScoreSingle(seen1, seen2, b)
			}, 0)
		}

		getNeedScoreSingle = function(seen1, seen2, key) {
			diff = seen2 >< key => seen1{key} - seen2{key} | seen1{key} + 1;
			diff > 0 => diff | 0
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
			theirSeen = ent:seen{subscriber};
			mySeen = ent:seen{meta:picoId};
			rumorScore = RUMOR_FACTOR * getNeedScore(mySeen, theirSeen);
			seenScore = SEEN_FACTOR * getNeedScore(theirSeen, mySeen);
			type = seenScore > rumorScore => "seen" | "rumor";
			msg = seenScore > rumorScore => buildSeen() | buildRumorFor(theirSeen);
			[type, rumor]
		}

		buildSeen = function(mySeen) {
			id = meta:picoId;
			{
				"picoId": id,
				"seen": ent:seen{id}
			}
		}

		buildRumorFor = function(seen) {
			sensorId = chooseRandomly(seen, "key", function(v, k) {
				mine = ent:seen{meta:picoId};
				getNeedScoreSingle(mine, seen, k)
			});
			latest = ent:seen{sensorId};
			needed = latest + 1;
			ent:rumors{[sensorId, needed]}
		}

		randomlyChoose = function(aMap, toChoose, aFunction) {
			scores = aMap.map(aFunction);
			bounds = scores.keys().reduce(function(a, b) {
				addable = {
					"key": k,
					"value": v,
					"min": a{"total"}
				};
				a = a.put("total", a{"total"} + scores{b});
				addable.put("max", a{"total"} - 1);
			}, {"total": 0});
			rand = random:integer(bounds{"total"} - 1);
			bounds = bounds.delete(["total"]);
			bounds.filter(function(v, k) {
				rand >= v{"min"} && rand <= v{"max"}
			}).values(){[0, toChoose]}
		}

		send = defaction(subscriber, m, type) {
			info = id_to_sub{subscriber};
			event:send({
				"eci": info{"channel"},
				"host": info{"host"},
				"domain": "gossip",
				"type": type,
				"attrs": m
			})
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
			info = preparedMessage(subscriber)
			type = info[0]
			m = info[1]
		}
		send(subscriber, m, type)
		fired {
			addable = type == "rumor" => 1 | 0;
			path = [subscriber, m{"SensorID"}];
			ent:seen{path} := ent:seen{path} + addable
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
		pre {
			id = event:attr("picoId")
			seen = event:attr("seen")
		}
		fired {
			ent:seen{id} := seen
		}
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
					"Tx_role": "node",
					"picoId": meta:picoId
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

	rule handle_node_subscription {
		select when wrangler inbound_pending_subscription_added
			where Tx_role == "node"
		event:send({
				"eci": event:attr("Tx"),
				"host": event:attr("Tx_host"),
				"domain": "gossip",
				"type": "new_id_sub_pair",
				"attrs": {
					"id": meta:picoId,
					"channel": event:attr("Rx"),
					"host": meta:host
				}
			})
		fired {
			raise gossip event "new_id_sub_pair"
				attributes {
					"id": event:attr("picoId"),
					"channel": event:attr("Tx"),
					"host": event:attr("Tx_host")
				}
		}
	}

	rule store_id_to_sub {
		select when gossip new_id_sub_pair
		fired {
			ent:id_to_sub := ent:id_to_sub.defaultsTo({});
			ent:id_to_sub{event:attr("id")} := {
				"channel": event:attr("channel"),
				"host": event:attr("host")
			}
		}
	}

}