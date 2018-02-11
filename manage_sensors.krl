ruleset manage_sensors {
	
	meta {
		name "Manage Sensors"
		shares __testing
	}

	global {

		__testing = {
			"events": [
				{
					"domain": "sensor",
					"type": "new_sensor",
					"attrs": []
				}
			]
		}
	
	}

	rule new_sensor {
		select when sensor new_sensor
		pre {
			a = "asdf"
			a = a.klog("ABC")
		}
		fired {
			a = a.klog("DEF");
			raise pico event "new_child_request"
				attributes { "dname": "a", "color": "#FF69B4" }
		}
		
	}

}