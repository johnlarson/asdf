ruleset wovyn_base {
	
	meta {
		name "Wovyn Base"
		use module secrets
		use module twilio with
			sid = keys:twilio{"sid"} and
			auth_token = keys:twilio{"auth_token"}
		use module sensor_profile
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
				},
				{
					"domain": "wovyn",
					"type": "heartbeat",
					"attrs": ["data"]
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
			generic = event:attr("genericThing").klog()
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
		twilio:send(secrets:my_number, secrets:twilio_number, "Too hot!")
	}

	rule accept_parent_subscription {
		select when wrangler inbound_pending_subscription_added
		pre {
			a = event:attrs.klog("ACCEPT!!!")
		}
		fired {
			raise wrangler event "pending_subscription_approval"
				attributes event:attrs
		}
	}

}