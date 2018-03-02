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
				},
				{
					"domain": "sensor",
					"type": "unneeded_sensor",
					"attrs": ["name"]
				}
			]
		}

		sensors = function() {
			ent:sensors
		}
	
	}

	rule new_sensor {
		select when sensor new_sensor where not(ent:sensors >< name)
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

	rule delete_sensor {
		select when sensor unneeded_sensor
		pre {
			name = event:attr("name")
		}
		send_directive("deleting_sensor", {"name": name})
		fired {
			raise wrangler event "child_deletion"
				attributes {"name": name};
			clear ent:sensors{name}
		}
	}

	rule sensor_created {
		select when wrangler child_initialized
		pre {
			name = event:attr("name")
			sensor = {
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