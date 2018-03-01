ruleset manage_sensors {
	
	meta {
		name "Manage Sensors"
		use module secrets
		shares __testing, sensors
	}

	global {

		__testing = {
			"queries": [
				{
					"name": "sensors",
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
					"domain": "sensor",
					"type": "clear_sensors",
					"attrs": []
				}
			]
		}

		sensors = function() {
			ent:sensors
		}
	
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
					"name": event:attr("name")
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
			name = event:attr("name")
			sensor = {
				"name": event:attr("name"),
				"id": event:attr("id"),
				"eci": event:attr("eci"),
				"parent_eci": event:attr("parent_eci")
			}
		}
		fired {
			ent:sensors := ent:sensors.defaultsTo({});
			ent:sensors{name} := sensor
		}
	}

}