ruleset manage_sensors {
	
	meta {
		name "Manage Sensors"
		use module secrets
		use module sky
		use module io.picolabs.subscription alias subscriptions
		use module io.picolabs.wrangler alias wrangler
		shares __testing, sensors, temperatures, get_channel, latest_reports
	}

	global {

		__testing = {
			"queries": [
				{
					"name": "latest_reports",
					"args": []
				},
				{
					"name": "sensors",
					"args": []
				},
				{
					"name": "temperatures",
					"args": []
				}
			],
			"events": [
				{
					"domain": "manager",
					"type": "temp_report_needed",
					"attrs": []
				},
				{
					"domain": "sensor",
					"type": "new_sensor",
					"attrs": ["name"]
				},
				{
					"domain": "manager",
					"type": "sensor_subscription_desired",
					"attrs": ["Tx", "Tx_host"]
				},
				{
					"domain": "manager",
					"type": "sensor_unsubscribe_desired",
					"attrs": ["Rx"]
				},
								{
					"domain": "sensor",
					"type": "nuke",
					"attrs": []
				},
				{
					"domain": "manager",
					"type": "remove_subscriptions",
					"attrs": []
				},
				{
					"domain": "sensor",
					"type": "unneeded_sensor",
					"attrs": ["name"]
				}
			]
		}

		sensors = function() {
			subscriptions:established("Tx_role", "sensor")
		}

		temperatures = function() {
			sensors().reduce(function(a, b) {
				host = b{"Tx_host"};
				channel = b{"Tx"};
				temps = sky:query(host, channel, "temperature_store", "temperatures");
				a.put([channel], temps)
			}, {})
		}

		latest_reports = function() {
			ent:reports.keys().filter(function(x) {
				x > ent:next_cid - 5
			}).reduce(function(a, b) {
				a.put([b], ent:reports{b})
			}, {});
		}

		DEFAULT_THRESHOLD = 100
	
	}

	rule new_sensor {
		select when sensor new_sensor
		pre {
			name = event:attr("name")
		}
		fired {
			raise wrangler event "child_creation"
				attributes {
					"rids": [
						"temperature_store",
						"wovyn_base",
						"sensor_profile",
						"io.picolabs.subscription"
					],
					"name": name,
					"is_sensor": true
				};
		}
	}

	rule delete_sensor {
		select when sensor unneeded_sensor
		pre {
			name = event:attr("name");
		}
		fired {
			raise wrangler event "child_deletion"
				attributes {"name": name};
		}
	}

	rule initialize_profile {
		select when manager child_sensor_subscribed where event:attr("Tx_role") == "sensor"
		event:send({
			"eci": event:attr("Tx"),
			"domain": "sensor",
			"type": "profile_updated",
			"attrs": {
				"name": event:attr("name"),
				"phone": secrets:my_number,
				"threshold": DEFAULT_THRESHOLD
			}
		})
	}

	rule subscribe_to_sensor_on_initialized {
		select when wrangler child_initialized where event:attr("rs_attrs"){"is_sensor"}
		fired {
			raise manager event "sensor_subscription_desired"
				attributes {"Tx": event:attr("eci")}
		}
	}

	rule subscribe_to_sensor {
		select when manager sensor_subscription_desired
		fired {
			raise wrangler event "subscription"
				attributes {
					"channel_type": "subscription",
					"Tx_host": event:attr("Tx_host"),
					"wellKnown_Tx": event:attr("Tx"),
					"Rx_role": "manager",
					"Tx_role": "sensor"
				}
		}
	}

	rule unsubscribe_sensor {
		select when manager sensor_unsubscribe_desired
		fired {
			raise wrangler event "subscription_cancellation"
				attributes {"Rx": event:attr("Rx")};
		}
	}

	rule nuke {
		select when sensor nuke
		fired {
			raise sensor event "clear_all" attributes {};
			raise manager event "remove_subscriptions" attributes {}
		}
	}

	rule clear_all {
		select when sensor clear_all
		foreach wrangler:children() setting (child)
		fired {
			raise sensor event "unneeded_sensor"
				attributes {"name": child{"name"}}
		}
	}

	rule remove_subscriptions {
		select when manager remove_subscriptions
		foreach sensors() setting (subscription)
		fired {
			raise wrangler event "subscription_cancellation"
				attributes {"Rx": subscription{"Rx"}}
		}
	}

	rule handle_need_temperature_report {
		select when manager temp_report_needed
		fired {
			ent:next_cid := ent:next_cid.defaultsTo(0) + 1;
			ent:reports := ent:reports.defaultsTo({});
			ent:reports{ent:next_cid} := {
				"temperature_sensors": sensors().length(),
				"responding": 0,
				"temperatures": {}
			};
			raise manager event "temp_report_cid_generated"
				attributes {"cid": ent:next_cid}
		}
	}

	rule notify_need_temperature_report {
		select when manager temp_report_cid_generated
		foreach sensors() setting (sensor)
		event:send({
			"eci": sensor{"Tx"},
			"host": sensor{"Tx_host"},
			"domain": "sensor",
			"type": "temp_report_needed",
			"attrs": {
				"cid": event:attr("cid"),
				"Rx": sensor{"Tx"},
				"Tx": sensor{"Rx"},
				"Tx_host": meta:host
			}
		})
	}

	rule add_temperature_report {
		select when sensor temp_report_generated
		pre {
			cid = event:attr("cid");
			report = ent:reports{cid};
			Tx = event:attr("Tx");
			temps = event:attr("temperatures")
		}
		fired {
			ent:reports{[cid, "responding"]} := report{"responding"} + 1;
			ent:reports{[cid, "temperatures", Tx]} := temps
		}
	}

}