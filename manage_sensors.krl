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
			a = a.klog("HM?")
		}
		
	}

}