ruleset wovyn_base {
	
	meta {
		name "Wovyn Base"
		shares __testing
	}

	global {
		__testing = {
			"events": [
				{
					"domain": "wovyn",
					"type": "heartbeat",
					"attrs": []
				}
			]
		}
		temperature_threshold = 100
	}

	rule process_heartbeat {
		select when wovyn heartbeat where data.decode()["genericThing"]
		pre {
			data = event:attr("data").decode()
			generic = data["genericThing"].klog("GENERIC")
		}
		send_directive("heartbeat", data)
		fired {
			raise wovyn event "new_temperature_reading"
				attributes {
					"temperature": generic["data"]["temperature"][0]["temperatureF"],
					"timestamp": generic["heartBeatSeconds"]
				}
		}
	}

	rule find_high_temps {
		select when wovyn new_temperature_reading
		pre {
			temp = event:attr("temperature")
			too_hot = temp > temperature_threshold
		}
		send_directive("temp_threshold", {"threshold_violation": too_hot})
		fired {
			raise wovyn event "threshold_violation"
				attributes event:attrs()
				if too_hot
		}
	}

}