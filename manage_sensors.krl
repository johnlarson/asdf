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
				attributes { "color": "#FF69B4" };
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
			"eid": "install_ruleset",
			"domain": "pico",
			"type": "new_ruleset",
			"attrs": {
				"rids": [
					"temperature_store",
					"sensor_profile"
				]
			}
		})
		fired {
			a = sensor.klog("FIRED");
			ent:sensors := ent:sensors.defaultsTo({});
			ent:sensors{sensor{"id"}} := sensor
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