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
		select when sensor new_sensor where not(ent:name_to_channel >< name)
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
		}
	}

	rule delete_sensor {
		select when sensor unneeded_sensor
		pre {
			name = event:attr("name");
		}
		send_directive("deleting_sensor", {"name": name})
		fired {
			raise wrangler event "child_deletion"
				attributes {"name": name};
			raise wrangler event "subscription_cancellation"
				attributes {"Rx": ent:name_to_channel{name}};
			clear ent:name_to_channel{name}
		}
	}

	rule add_sensor_to_database {
		select when manager child_sensor_subscribed where name
		fired {
			ent:name_to_channel := ent:name_to_channel.defaultsTo({});
			ent:name_to_channel{event:attr("name")} := event:attr("Rx");
		}
	}

	rule initialize_profile {
		select when wrangler child_initialized where is_child_sensor(name)
		pre {
			name = event:attr("rs_attrs"){"name"}
		}
		event:send({
			"eci": event:attr("eci"),
			"domain": "sensor",
			"type": "profile_updated",
			"attrs": {
				"name": name,
				"phone": secrets:my_number,
				"threshold": DEFAULT_THRESHOLD
			}
		})
	}

	rule subscribe_to_sensor {
		select when wrangler child_initialized
		fired {
			raise wrangler event "subscription"
				attributes {
					"name": event:attr("name"),
					"channel_type": "subscription",
					"wellKnown_Tx": event:attr("eci"),
					"Rx_role": "manager",
					"Tx_role": "child_sensor"
				}
		}
	}

	rule clear_all {
		select when sensor clear_sensors
		foreach ent:sensors setting (sensor, name)
		fired {
			raise sensor event "unneeded_sensor"
				attributes {"name": name}
		}
	}

}