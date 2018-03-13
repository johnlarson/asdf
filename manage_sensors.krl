ruleset manage_sensors {
	
	meta {
		name "Manage Sensors"
		use module secrets
		use module sky
		use module io.picolabs.subscription alias subscriptions
		use module io.picolabs.wrangler alias wrangler
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
				channel = b{"Tx"};
				temps = sky:query(channel, "temperature_store", "temperatures");
				a.put([channel], temps)
			}, {})
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

}