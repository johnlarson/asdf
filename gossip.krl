ruleset gossip {

	meta {
		name "Gossip"
		shares __testing, getPeer, sandbox
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
				},
				{
					"name": "sandbox",
					"args": []
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

		sandbox = function() {
			[][0].klog("ZERO");
			[][-1].klog("NEG")
		}

		getPeer = function() {
			a.klog("START getPeer");
			ids = ent:id_to_sub.keys().klog("\tIDS");
			a.klog("\tLOOP chooseRandomly");
			seen = ent:seen.delete(meta:picoId);
			seen.klog("SEEN");
			seen.klog("\t\tMAP (seen)");
			"key".klog("\t\tTO_CHOOSE");
			chooseRandomly(ent:seen, "key", function(v, k) {
				[v, k].klog("\t\tV,K");
				getMyNeedScore(v).klog("\t\t\tNEED_SCORE");
			}, ids[random:integer(0, ids.length() - 1)].klog("\t\tDEFAULT")).klog("RET getPeer");
		}

		getMyNeedScore = function(seen) {
			a.klog("START getMyNeedScore");
			seen.klog("\tSEEN");
			mySeen = ent:seen{meta:picoId}.defaultsTo({}).klog("\tMY_SEEN");
			rumorScore = getNeedScore(mySeen, seen).klog("\tRUMOR_SCORE");
			seenScore = getNeedScore(seen, mySeen).klog("\tSEEN_SCORE");
			(RUMOR_FACTOR * rumorScore + SEEN_FACTOR * seenScore).klog("RET getMyNeedScore")
		}

		getNeedScore = function(seen1, seen2) {
			a.klog("START getNeedScore");
			seen1.klog("\tSEEN1");
			seen2.klog("\tSEEN2");
			a.klog("\tLOOP seen1.keys().reduce");
			seen1.keys().reduce(function(a, b) {
				[a, b].klog("\t\tA, B");
				(a + getNeedScoreSingle(seen1, seen2, b)).klog("\t\tREDUCE RET")
			}, (0).klog("\t\tDEFAULT")).klog("RET getNeedScore")
		}

		getNeedScoreSingle = function(seen1, seen2, key) {
			a.klog("START getNeedScoreSingle");
			seen1.klog("\tSEEN1");
			seen2.klog("\tSEEN2");
			key.klog("\tKEY");
			diff = seen2 >< key => seen1{key} - seen2{key} | seen1{key} + 1;
			diff.klog("\tDIFF");
			(diff > 0 => diff | 0).klog("RET getNeedScoreSingle")
		}

		getNextSequenceNumber = function() {
			a.klog("START getNextSequenceNumber");
			id = meta:picoId;
			id.klog("\tID");
			(ent:seen{[id, id]} != null => maxSelfKnown(id) + 1 | 0).klog("RET getNextSequenceNumber")
		} 

		maxSelfKnown = function(id) {
			a.klog("START maxSelfKnown");
			id.klog("\tID");
			forId = ent:rumors{id}.defaultsTo([]);
			forId.klog("\tFOR_ID");
			idx = forId.index(null);
			idx.klog("\tIDX");
			(idx == -1 => forId.length() - 1 | idx - 1).klog("RET maxSelfKnown")
		}

		preparedMessage = function(subscriber) {
			a.klog("START preparedMessage");
			subscriber.klog("\tSUBSCRIBER");
			theirSeen = ent:seen{subscriber};
			theirSeen.klog("\tTHEIR_SEEN");
			mySeen = ent:seen{meta:picoId}.defaultsTo({});
			mySeen.klog("\tMY_SEEN");
			rumorScore = RUMOR_FACTOR * getNeedScore(mySeen, theirSeen);
			rumorScore.klog("\tRUMOR SCORE");
			seenScore = SEEN_FACTOR * getNeedScore(theirSeen, mySeen);
			seenScore.klog("\tSEEN SCORE");
			type = (not(ent:rumors) || seenScore > rumorScore) => "seen" | "rumor";
			type.klog("\tTYPE");
			msg = type == "seen" => buildSeen() | buildRumorFor(theirSeen);
			msg.klog("\tMSG");
			[type, msg].klog("RET preparedMessage")
		}

		buildSeen = function(mySeen) {
			a.klog("START buildSeen");
			mySeen.klog("\tMY_SEEN");
			id = meta:picoId;
			id.klog("\tID");
			seen = ent:seen{id}.defaultsTo({}).klog("SEEN 1");
			seen.klog("\tSEEN");
			{
				"picoId": id,
				"seen": seen
			}.klog("RET buildSeen")
		}

		buildRumorFor = function(seen) {
			a.klog("START buildRumorFor");
			seen.klog("\tSEEN");
			a.klog("\tLOOP chooseRandomly");
			seen.klog("\t\tMAP (seen)");
			"key".klog("\t\tTO_CHOOSE");
			null.klog("\t\tDEFAULT");
			sensorId = chooseRandomly(seen, "key", function(v, k) {
				[v, k].klog("\t\tV, K");
				mine = ent:seen{meta:picoId};
				mine.klog("\t\t\tMINE");
				getNeedScoreSingle(mine, seen, k).klog("\t\t\tNEED_SCORE")
			});
			sensorId.klog("\tSENSOR_ID");
			latest = sensorId => ent:seen{sensorId} | -1;
			latest.klog("\tLATEST");
			ids = ent:rumors.keys();
			ids.klog("\tIDS");
			sensorId.defaultsTo(ids[random:integer(0, ids.length() - 1)]);
			sensorId.klog("\tSENSOR ID DEFAULTED");
			needed = latest + 1;
			needed.klog("\tNEEDED");
			(sensorId => ent:rumors{[sensorId, needed]}.klog("\tBY PATH") | getRandomRumor().klog("\tTOTALLY RANDOM")).klog("RET buildRumorFor")
		}

		getRandomRumor = function() {
			rumors = ent:rumors
				.klog("RUMORS")
				.values()
				.klog("VALUES")
				.reduce(function(a, b) {a.append(b)}, [])
				.klog("REDUCED");
			rumors[random:integer(rumors.length() - 1)]
		}

		chooseRandomly = function(aMap, toChoose, aFunction, default = null) {
			a.klog("START chooseRandomly");
			aMap.klog("\tA_MAP");
			toChoose.klog("\tTO_CHOOSE");
			default.klog("\tDEFAULT");
			result = (((aMap == {}).klog("\tA_MAP EMPTY?") || (aMap == null).klog("\tA_MAP NULL?")).klog("\tNOTHING IN A_MAP?") => default | chooseRandomlyNoDefault(aMap, toChoose, aFunction)).klog("RET chooseRandomly");
			result == null => default | result
		}

		chooseRandomlyNoDefault = function(aMap, toChoose, aFunction) {
			a.klog("START chooseRandomlyNoDefault");
			aMap.klog("\tA_MAP");
			toChoose.klog("\tTO_CHOOSE");
			scores = aMap.map(aFunction);
			scores.klog("\tSCORES");
			a.klog("\tREDUCE scores.keys()");
			bounds = scores.keys().reduce(function(a, b) {
				[a, b].klog("\t\tA, B");
				addable = {
					"key": b,
					"value": scores[b].klog("\t\t\tSCORES[B]"),
					"min": a{"total"}.klog("\t\t\tA{'TOTAL'}")
				};
				addable.klog("\t\t\tADDABLE");
				a = a.put("total", a{"total"} + scores{b});
				a.klog("\t\t\tA");
				addable = addable.put("max", a{"total"} - 1);
				addable.klog("\t\t\tADDABLE");
				(addable{"max"} >= addable{"min"} => a.put(b, addable) | a).klog("\t\tREDUCE RET")
			}, {"total": 0}.klog("\t\tDEFAULT"));
			rand = random:integer(bounds{"total"} - 1);
			rand.klog("\tRAND");
			bounds = bounds.delete(["total"]);
			bounds.klog("\tBOUNDS");
			a.klog("\tFILTER bounds");
			bounds.filter(function(v, k) {
				[v, k].klog("\t\tV, K");
				(rand >= v{"min"} && rand <= v{"max"}).klog("\t\tFILTER RET")
			}).values(){[0, toChoose]}.klog("RET chooseRandomlyNoDefault")
		}

		send = defaction(subscriber, m, type) {
			x = a.klog("START send");
			x = subscriber.klog("\tSUBSCRIBER");
			x = m.klog("\tM");
			x = type.klog("\tTYPE");
			info = ent:id_to_sub{subscriber};
			x = info.klog("\tINFO");
			event:send({
				"eci": info{"channel"},
				"host": info{"host"},
				"domain": "gossip",
				"type": type,
				"attrs": m
			}.klog("END send, sending:"));
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
			//raise gossip event "heartbeat" attributes {}
		}
	}

	rule gossip {
		select when gossip heartbeat where ent:id_to_sub
		pre {
			x = a.klog("START gossip")
			x = event:attrs.klog("\tATTRS")
			x = a.klog("\tPRE")
			subscriber = getPeer().klog("\t\tSUBSCRIBER")
			info = preparedMessage(subscriber).klog("\t\tINFO")
			type = info[0].klog("\t\tTYPE")
			m = info[1].klog("\t\tM")
			event_to_raise = type == "rumor" => "sent_rumor" | "nothing"
		}
		send(subscriber, m, type)
		fired {
			a.klog("\tFIRED");
			raise gossip event event_to_raise
				attributes {
					"subscriber": subscriber,
					"m": m
				}.klog("\t\tRAISING ATTRS");
			event_to_raise.klog("\t\tEVENT RAISED");
			a.klog("END gossip")
		}
	}

	rule store_own_rumor {
		select when gossip sent_rumor
		pre {
			subscriber = event:attr("subscriber")
			m = event:attr("m")
			req = m{"MessageID"}.split(":")[1]
			path = [subscriber, m{"SensorID"}]
		}
		fired {
			a.klog("START store_own_rumor");
			event:attrs.klog("\tATTRS");
			path.klog("\tPATH");
			ent:seen.klog("\tENT:SEEN BEFORE");
			ent:seen{subscriber} := ent:seen{subscriber}.defaultsTo({});
			ent:seen{subscriber}.klog("ENT:SEEN{SUBSCRIBER}");
			prev_highest = ent:seen{path}.defaultsTo(-1);
			prev_highest.klog("PREV_HIGHEST");
			ent:seen{path} := req == prev_highest + 1 => req | prev_highest;
			ent:seen.klog("\tENT:SEEN AFTER");
			a.klog("END store_own_rumor")
		}
	}

	rule set_gossip_timeout {
		select when gossip heartbeat
		fired {
			//schedule gossip event "heartbeat"
			//	at time:add(time:now(), {"ms": INTERVAL})
			//	attributes {}
		}
	}

	rule receive_rumor {
		select when gossip rumor
		pre {
			x = a.klog("START receive_rumor")
			x = event:attrs.klog("\tATTRS")
			x = a.klog("\tPRE")
			mid = event:attr("MessageID").klog("\t\tMID")
			parts = mid.split(":").klog("\t\tPARTS")
			id = parts[0].klog("\t\tID")
			seq = parts[1].klog("\t\tSEQ")
			me = meta:picoId.klog("\t\tME")
		}
		fired {
			a.klog("\tFIRED");
			ent:rumors := ent:rumors.defaultsTo({});
			ent:rumors.klog("\t\tENT:RUMORS");
			ent:rumors{id} := ent:rumors{id}.defaultsTo([]);
			ent:rumors{id}.klog("\t\tENT:RUMORS{ID}");
			ent:rumors{[id, seq]} := event:attrs;
			ent:rumors{[id, seq]}.klog("\t\tENT:RUMORS{[ID, SEQ]}");
			ent:seen := ent:seen.defaultsTo({});
			ent:seen.klog("\t\tENT:SEEN");
			ent:seen{me} := ent:seen{me}.defaultsTo({});
			ent:seen{me}.klog("\t\tENT:SEEN{ME}");
			ent:seen{[me, id]} := maxSelfKnown(id);
			ent:seen{[me, id]}.klog("\t\tENT:SEEN{[ME, ID]}");
			a.klog("END receive_rumor")
		}
	}

	rule receive_seen {
		select when gossip seen
		pre {
			x = a.klog("START receive_rumor")
			x = event:attrs.klog("ATTRS")
			x = a.klog("\tPRE")
			id = event:attr("picoId").klog("\t\tID")
			seen = event:attr("seen").klog("\t\tSEEN")
		}
		fired {
			a.klog("\tFIRED");
			ent:seen := ent:seen.defaultsTo({});
			ent:seen.klog("\t\tENT:SEEN");
			ent:seen{id} := seen;
			ent:seen{id}.klog("\t\tENT:SEEN{ID}");
			a.klog("END receive_seen")
		}
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

	rule init_subscription_seen_info {
		select when gossip new_id_sub_pair
		fired {
			
		}
	}

}