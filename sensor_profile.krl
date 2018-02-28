ruleset sensor_profile {

	meta {
		name "profile"
		shares __testing, profile
		provides profile
	}

	global {

		__testing = {
			"queries": [
				{
					"name": "profile",
					"args": []
				}
			],
			"events": [
				{
					"domain": "sensor",
					"type": "profile_updated",
					"attrs": ["location", "name", "threshold", "phone"]
				}
			]
		}

		profile = function() {
			{
				"location": ent:location,
				"name": ent:name,
				"threshold": ent:threshold,
				"phone": ent:phone
			}
		}

	}
	
	rule update {
		select when sensor profile_updated

		pre {
			location = event:attr("location").klog("LOC")
			name = event:attr("name")
			threshold = event:attr("threshold").decode()
			phone = event:attr("phone")
		}

		fired {
			ent:location := location.defaultsTo(ent:location);
			ent:name := name.defaultsTo(ent:name);
			ent:threshold := threshold.defaultsTo(ent:threshold);
			ent:phone := phone.defaultsTo(ent:phone);
		}

	}

	rule initialize_profile {
		select when wrangler ruleset_added where rids >< "sensor_profile"
		pre {
			a = event:attrs().klog("INIT ATTRS")
		}
		fired {
			raise sensor event "profile_updated"
				attributes {
					"name": sensor{"name"},
					"phone": secrets:my_number,
					"threshold": DEFAULT_THRESHOLD
				}
		}
	}

}