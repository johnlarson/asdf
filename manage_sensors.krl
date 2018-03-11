ruleset manage_sensors {
	
	meta {
		name "Manage Sensors"
		use module secrets
		use module sky
		use module io.picolabs.subscription alias subscriptions
		shares __testing, sensors, temperatures, get_channel
	}

	global {

		__testing = {
			"queries": [
				{
					"name": "sensors",
					"args": []
				},
				{
					"name": "temperatures",
					"args": []
				},
				{
					"name": "get_channel",
					"args": ["name"]
				}
			],
			"events": [
				{
					"domain": "sensor",
					"type": "new_sensor",
					"attrs": ["name"]
				},
				{
					"domain": "manager",
					"type": "sensor_subscription_desired",
					"attrs": ["Tx"]
				},
				{
					"domain": "manager",
					"type": "sensor_unsubscribe_desired",
					"attrs": ["Rx"]
				},
				{
					"domain": "sensor",
					"type": "unneeded_sensor",
					"attrs": ["name"]
				},
				{
					"domain": "sensor",
					"type": "clear_sensors",
					"attrs": []
				}
			]
		}

		sensors = function() {
			subscriptions:established("Tx_role", "child_sensor")
		}

		temperatures = function() {
			sensors().reduce(function(a, b) {
				channel = b{"Tx"};
				temps = sky:query(channel, "temperature_store", "temperatures");
				a.put([channel], temps)
			}, {})
		}

		is_child_sensor = function(name) {
			ent:name_to_channel >< name
		}

		get_channel = function(name) {
			ent:name_to_channel{name}
		}

		DEFAULT_THRESHOLD = 100
	
	}

	rule new_sensor {
		select when sensor new_sensor where not(is_child_sensor(name))
		fired {
			raise wrangler event "child_creation"
				attributes {
					"rids": [
						"temperature_store",
						"wovyn_base",
						"sensor_profile",
						"io.picolabs.subscription"
					],
					"name": event:attr("name")
				};
			ent:children := ent:children.defaultsTo({});
			ent:children{event:attr("name")} = true
		}
	}

	rule delete_sensor {
		select when sensor unneeded_sensor
		pre {
			name = event:attr("name");
			Tx = ent:name_to_channel{name}
		}
		send_directive("deleting_sensor", {"name": name})
		fired {
			raise wrangler event "child_deletion"
				attributes {"name": name};
			raise manager event "sensor_unsubscribe_desired"
				attributes {"Rx": Rx};
			clear ent:children{name}
		}
	}

	rule add_sensor_to_database {
		select when manager child_sensor_subscribed where event:attr("name")
		fired {
			ent:name_to_channel := ent:name_to_channel.defaultsTo({});
			ent:name_to_channel{event:attr("name")} := event:attr("Rx");
			ent:channel_to_name := ent:channel_to_name.defaultsTo({});
			ent:channel_to_name{event:attr("Rx")} := event:attr("name")
		}
	}

	rule initialize_profile {
		select when manager child_sensor_subscribed where event:attr("Tx_role") == "child_sensor"
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
		select when wrangler child_initialized
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
					"wellKnown_Tx": event:attr("Tx"),
					"Rx_role": "manager",
					"Tx_role": "child_sensor"
				}
		}
	}

	rule unsubscribe_sensor {
		select when manager sensor_unsubscribe_desired
		fired {
			raise wrangler event "subscription_cancellation"
				attributes {"Rx": event:attr("Rx")};
			clear ent:name_to_channel{ent:channel_to_name{event:attr("Rx")}};
			clear ent:channel_to_name{event:attr("Rx")}
		}
	}

	rule clear_all {
		select when sensor clear_sensors
		foreach ent:children setting (v, name)
		fired {
			raise sensor event "unneeded_sensor"
				attributes {"name": name}
		}
	}

}