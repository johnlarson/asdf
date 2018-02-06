ruleset wovyn_base {
	
	meta {
		name "Wovyn Base"
		use module secrets
		use module twilio with
			sid = keys:twilio{"sid"} and
			auth_token = keys:twilio{"auth_token"}
		shares __testing
	}

	global {
		__testing = {
			"events": [
				{
					"domain": "sensor",
					"type": "reading_reset",
					"attrs": []
				}
			]
		}
		TEMPERATURE_THRESHOLD = 100
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
			too_hot = temp > TEMPERATURE_THRESHOLD
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

}