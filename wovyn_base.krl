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
	}

	rule process_heartbeat {
		select when wovyn heartbeat where data.decode()["genericThing"]
		pre {
			data = event:attr("data").decode()
			generic = data["genericThing"]
		}
		send_directive("heartbeat", data)
		fired {
			raise wovyn event "new_temperature_reading"
				attributes {
					"temperature": generic["data"]["temperature"]["temperatureF"],
					"timestamp": generic["heartBeatSeconds"]
				}
		}
	}

}