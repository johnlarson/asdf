ruleset gossip {

	meta {
		name "Gossip"
		shares __testing, reports, isOn
	}

	global {

		__testing = {
			"queries": [
				{
					"name": "reports",
					"args": []
				},
				{
					"name": "isOn",
					"args": []
				}
			],
			"events": [
				{
					"domain": "gossip",
					"type": "toggle",
					"attrs": []
				},
								{
					"domain": "gossip",
					"type": "add_subscription",
					"attrs": ["wellKnown_Tx", "Tx_host"]
				},
				{
					"domain": "gossip",
					"type": "heartbeat",
					"attrs": []
				},
				{
					"domain": "gossip",
					"type": "process",
					"attrs": ["status"]
				}
			]
		}

		INTERVAL = 5
		RUMOR_FACTOR = 1
		KNOWN_FACTOR = 1

		reports = function() {
			ent:rumors
		}

		getPeer = function() {
			ids = ent:id_to_sub.keys();
			seen = ent:seen.delete(meta:picoId);
			chooseRandomly(ent:seen, "key", function(v, k) {
				getMyNeedScore(v)
			}, ids[random:integer(0, ids.length() - 1)])
		}

		getMyNeedScore = function(seen) {
			mySeen = ent:seen{meta:picoId}.defaultsTo({});
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
			s1 = seen1{key};
			s1 = s1 == null => -1 | s1;
			s2 = seen2{key};
			s2 = s2 == null => -1 |s2;
			diff = seen2 >< key => seen1{key} - seen2{key} | seen1{key} + 1;
			(diff > 0 => diff | 0)
		}

		getNextSequenceNumber = function() {
			id = meta:picoId;
			ent:seen{[id, id]} != null => maxSelfKnown(id) + 1 | 0
		} 

		maxSelfKnown = function(id) {
			forId = ent:rumors{id}.defaultsTo([]);
			idx = forId.index(null);
			idx == -1 => forId.length() - 1 | idx - 1
		}

		preparedMessage = function(subscriber) {
			theirSeen = ent:seen{subscriber};
			mySeen = ent:seen{meta:picoId}.defaultsTo({});
			rumorScore = RUMOR_FACTOR * getNeedScore(mySeen, theirSeen);
			seenScore = SEEN_FACTOR * getNeedScore(theirSeen, mySeen);
			options = {
				"seen": 50,
				"rumor": 50
			};
			type = chooseRandomly(options, "key", function(v, k) {v});
			type = ent:rumors && ent:rumors != {} => type | "seen";
			msg = type == "seen" => buildSeen() | buildRumorFor(theirSeen);
			[type, msg]
		}

		buildSeen = function(mySeen) {
			id = meta:picoId;
			seen = ent:seen{id}.defaultsTo({});
			{
				"picoId": id,
				"seen": seen
			}
		}

		buildRumorFor = function(seen) {
			mine = ent:seen{meta:picoId};
			sensorId = chooseRandomly(mine, "key", function(v, k) {
				getNeedScoreSingle(mine, seen, k)
			});
			ids = ent:rumors.keys();
			sensorId.defaultsTo(ids[random:integer(0, ids.length() - 1)]);
			latest = seen{sensorId}.defaultsTo(-1);
			needed = latest + 1;
			sensorId => ent:rumors{[sensorId, needed]} | getRandomRumor()
		}

		getRandomRumor = function() {
			rumors = ent:rumors
				.values()
				.reduce(function(a, b) {a.append(b)}, []);
			rumors[random:integer(rumors.length() - 1)]
		}

		chooseRandomly = function(aMap, toChoose, aFunction, default = null) {
			result = aMap == {} || aMap == null => default | chooseRandomlyNoDefault(aMap, toChoose, aFunction);
			result == null => default | result
		}

		chooseRandomlyNoDefault = function(aMap, toChoose, aFunction) {
			scores = aMap.map(aFunction);
			bounds = scores.keys().reduce(function(a, b) {
				addable = {
					"key": b,
					"value": scores[b],
					"min": a{"total"}
				};
				a = a.put("total", a{"total"} + scores{b});
				addable = addable.put("max", a{"total"} - 1);
				addable{"max"} >= addable{"min"} => a.put(b, addable) | a
			}, {"total": 0});
			rand = random:integer(bounds{"total"} - 1);
			bounds = bounds.delete(["total"]);
			bounds.filter(function(v, k) {
				rand >= v{"min"} && rand <= v{"max"}
			}).values(){[0, toChoose]}
		}

		isOn = function() {
			ent:is_on.defaultsTo(true)
		}

		send = defaction(subscriber, m, type) {
			info = ent:id_to_sub{subscriber};
			event:send({
				"eci": info{"channel"},
				"host": info{"host"},
				"domain": "gossip",
				"type": type,
				"attrs": m
			});
		}

	}

	rule init_own_seen {
		select when wrangler ruleset_added where rids >< meta:rid
		fired {
			ent:seen := ent:seen.defaultsTo({});
			ent:seen{meta:picoId} := ent:seen{meta:picoId}.defaultsTo({})
		}
	}

	rule start_gossiping {
		select when wrangler ruleset_added where rids >< meta:rid
		fired {
			raise gossip event "heartbeat" attributes {}
		}
	}

	rule gossip {
		select when gossip heartbeat where ent:id_to_sub && isOn()
		pre {
			subscriber = getPeer()
			info = preparedMessage(subscriber)
			type = info[0]
			m = info[1]
			event_to_raise = type == "nothing"
		}
		send(subscriber, m, type)
		fired {
			raise gossip event event_to_raise
				attributes {
					"subscriber": subscriber,
					"m": m
				};
		}
	}

	rule set_gossip_timeout {
		select when gossip heartbeat
		fired {
			schedule gossip event "heartbeat"
				at time:add(time:now(), {"s": INTERVAL})
				attributes {}
		}
	}

	rule receive_rumor {
		select when gossip rumor where isOn()
		fired {
			raise gossip event "rumor_received"
				attributes event:attrs
		}
	}

	rule handle_rumor {
		select when gossip rumor_received
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
			ent:seen{[me, id]} := maxSelfKnown(id);
		}
	}

	rule store_seen {
		select when gossip seen where isOn()
		pre {
			id = event:attr("picoId")
			seen = event:attr("seen")
		}
		fired {
			ent:seen := ent:seen.defaultsTo({});
			ent:seen{id} := seen;
		}
	}

	rule respond_seen {
		select when gossip seen where isOn()
		pre {
			subscriber = event:attr("picoId")
			seen = event:attr("seen")
			m = buildRumorFor(seen)
			has_rumors = ent:rumors && ent:rumors != {}
			event_to_raise = has_rumors => "rumor_ready" | "nothing"
		}
		fired {
			raise gossip event event_to_raise
				attributes {
					"subscriber": subscriber,
					"m": m
				}
		}
	}

	rule send_rumor {
		select when gossip rumor_ready
		pre {
			subscriber = event:attr("subscriber")
			m = event:attr("m")
		}
		send(subscriber, m, "rumor")
	}

	rule add_subscription {
		select when gossip add_subscription
		pre {
			me = meta:picoId
		}
		fired {
			ent:seen := ent:seen.defaultsTo({});
			ent:seen{me} := ent:seen{me}.defaultsTo({});
			raise wrangler event "subscription"
				attributes {
					"channel_type": "subscription",
					"Tx_host": event:attr("Tx_host"),
					"wellKnown_Tx": event:attr("wellKnown_Tx"),
					"Rx_role": "node",
					"Tx_role": "node",
					"picoId": meta:picoId,
					"seen": ent:seen{me}
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
			raise gossip event "rumor_received"
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
					"host": meta:host,
					"seen": ent:seen{meta:picoId}.defaultsTo({})
				}
			})
		fired {
			raise gossip event "new_id_sub_pair"
				attributes {
					"id": event:attr("picoId"),
					"channel": event:attr("Tx"),
					"host": event:attr("Tx_host"),
					"seen": event:attr("seen")
				}
		}
	}

	rule store_id_to_sub {
		select when gossip new_id_sub_pair
		pre {
			id = event:attr("id")
		}
		fired {
			ent:id_to_sub := ent:id_to_sub.defaultsTo({});
			ent:id_to_sub{id} := {
				"channel": event:attr("channel"),
				"host": event:attr("host")
			};
			ent:seen := ent:seen.defaultsTo({});
			ent:seen{id} := event:attr("seen")
		}
	}

	rule off_on {
		select when gossip process
		fired {
			ent:is_on := event:attr("status") == "on"
		}
	}

	rule toggle {
		select when gossip toggle
		fired {
			ent:is_on := not(isOn())
		}
	}

}