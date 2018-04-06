ruleset wovyn_base {
	
	meta {
		name "Wovyn Base"
		use module secrets
		use module twilio with
			sid = keys:twilio{"sid"} and
			auth_token = keys:twilio{"auth_token"}
		use module sensor_profile
		use module io.picolabs.wrangler alias wrangler
		use module io.picolabs.subscription alias subscriptions
		shares __testing
	}

	global {
		__testing = {
			"events": [
				{
					"domain": "sensor",
					"type": "reading_reset",
					"attrs": []
				},
				{
					"domain": "wovyn",
					"type": "fake_heartbeat",
					"attrs": ["temperature"]
				}
			]
		}
	}

	rule fake_heartbeat {
		select when wovyn fake_heartbeat
		pre {
			genericThing = {
				"data": {
					"temperature": [
						{
							"temperatureF": event:attr("temperature")
						}
					]
				}
			}
		}
		fired {
			raise wovyn event "heartbeat"
				attributes {
					"genericThing": genericThing
				}
		}
	}

	rule process_heartbeat {
		select when wovyn heartbeat where event:attr("genericThing")
		pre {
			generic = event:attr("genericThing")
		}
		send_directive("heartbeat", generic)
		fired {
			raise wovyn event "new_temperature_reading"
				attributes {
					"temperature": generic["data"]["temperature"][0]["temperatureF"],
					"timestamp": time:now()
				}
		}
	}

	rule find_high_temps {
		select when wovyn new_temperature_reading
		pre {
			temp = event:attr("temperature")
			threshold = sensor_profile:profile()["threshold"].defaultsTo(100)
			too_hot = temp > threshold
		}
		send_directive("temp_threshold", {"threshold_violation": too_hot})
		fired {
			raise wovyn event "threshold_violation"
				attributes event:attrs()
				if too_hot
		}
	}

	rule threshold_notification {
		select when wovyn threshold_violation
		foreach subscriptions:established("Tx_role", "manager") setting (subscription)
		event:send({
			"eci": subscription{"Tx"},
			"domain": "wovyn",
			"type": "threshold_violation",
			"attrs": event:attrs
		})
	}

	rule accept_subscription {
		select when wrangler inbound_pending_subscription_added
		fired {
			raise wrangler event "pending_subscription_approval"
				attributes event:attrs
		}
	}

	rule notify_manager_subscription_added {
		select when wrangler subscription_added
		event:send({
			"eci": event:attr("Tx"),
			"domain": "manager",
			"type": "child_sensor_subscribed",
			"attrs": {
				"name": wrangler:myself(){"name"},
				"Rx": event:attr("Tx"),
				"Rx_role": event:attr("Tx_role"),
				"Tx": event:attr("Rx"),
				"Rx": event:attr("Tx"),
				"Tx_role": event:attr("Rx_role")
			}
		})
	}

}