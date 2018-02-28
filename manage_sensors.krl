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
		pre {
			a = "asdf"
			a = a.klog("ABC")
		}
		fired {
			a = a.klog("DEF");
			raise wrangler event "child_creation"
				attributes {
					"color": "#FF69B4",
					"rids": [
						"temperature_store",
						"wovyn_base",
						"sensor_profile"
					]
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
			sensor = event:attrs().klog("ATTRS")
		}
		event:send({
			"eci": sensor{"eci"},
			"eid": "init_profile",
			"domain": "sensor",
			"type": "profile_updated",
			"attrs": {
				"location": "HELLO"
			}
		})
		fired {
			a = sensor.klog("FIRED");
			ent:sensors := ent:sensors.defaultsTo({});
			ent:sensors{sensor{"id"}} := sensor;
			ent:sensors.klog("SENSERS")

		}
	}

	rule initialize_profile {
		select when pico ruleset_added where event:attr("rids") >< "sensor_profile"
		pre {
			a = event:attrs().klog("INIT ATTRS")
		}
		fired {
			a = a.klog()
		}
	}

}