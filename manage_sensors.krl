ruleset manage_sensors {
	
	meta {
		name "Manage Sensors"
		use module secrets
		use module sky
		shares __testing, sensors, temperatures
	}

	global {

		__testing = {
			"queries": [
				{
					"name": "sensors",
					"args": []
				},
				{
					"name": "temperatures",
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
					"type": "unneeded_sensor",
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
			ent:sensors.defaultsTo({})
		}

		temperatures = function() {
			ent:sensors.map(function(v, k) {
				sky:query(v{"eci"}, "temperature_store", "temperatures")
			})
		}

		DEFAULT_THRESHOLD = 100
	
	}

	rule new_sensor {
		select when sensor new_sensor where not(ent:sensors >< name)
		fired {
			raise wrangler event "child_creation"
				attributes {
					"rids": [
						"temperature_store",
						"wovyn_base",
						"sensor_profile",
						"io.picolabs.subscription"
					],
					"name": event:attr("name")
				};
		}
	}

	rule delete_sensor {
		select when sensor unneeded_sensor
		pre {
			name = event:attr("name").klog("NAME")
		}
		send_directive("deleting_sensor", {"name": name})
		fired {
			raise wrangler event "child_deletion"
				attributes {"name": name};
			clear ent:sensors{name}
		}
	}

	rule add_sensor_to_database {
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

	rule initialize_profile {
		select when wrangler child_initialized 
		pre {
			name = event:attr("rs_attrs"){"name"}
		}
		event:send({
			"eci": event:attr("eci"),
			"domain": "sensor",
			"type": "profile_updated",
			"attrs": {
				"name": name,
				"phone": secrets:my_number,
				"threshold": DEFAULT_THRESHOLD
			}
		})
	}

	rule subscribe_to_sensor {
		select when wrangler child_initialized
		fired {
			raise wrangler event "subscription"
				attributes {
					"name": event:attr("name"),
					"channel_type": "subscription",
					"wellKnown_Tx": event:attr("eci")
				}
		}
	}

	rule clear_all {
		select when sensor clear_sensors
		foreach ent:sensors setting (sensor, name)
		fired {
			raise sensor event "unneeded_sensor"
				attributes {"name": name}
		}
	}

}