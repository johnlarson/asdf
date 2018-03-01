ruleset manage_sensors {
	
	meta {
		name "Manage Sensors"
		use module secrets
		shares __testing
	}

	global {

		__testing = {
			"events": [
				{
					"domain": "sensor",
					"type": "new_sensor",
					"attrs": ["name"]
				},
				{
					"domain": "sensor",
					"type": "clear_sensors",
					"attrs": []
				}
			]
		}

		DEFAULT_THRESHOLD = 100
	
	}

	rule new_sensor {
		select when sensor new_sensor
		fired {
			raise wrangler event "child_creation"
				attributes {
					"rids": [
						"temperature_store",
						"wovyn_base",
						"sensor_profile"
					],
					"name": event:attrs()
				};
		}
		
	}

	rule clear_sensors {
		select when sensor clear_sensors
		fired {
			ent:sensors := {}
		}
	}

	rule sensor_created {
		select when wrangler child_initialized
		pre {
			sensor = event:attrs()
		}
		fired {
			ent:sensors := ent:sensors.defaultsTo({});
			ent:sensors{sensor{"id"}} := sensor
		}
	}

}