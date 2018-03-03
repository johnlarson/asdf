ruleset sensor_profile {

	meta {
		name "profile"
		use module secrets
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
			name = event:attr("name")
			threshold = event:attr("threshold").decode()
			phone = event:attr("phone")
			location = event:attr("location")
		}

		fired {
			ent:location := location.defaultsTo(ent:location);
			ent:name := name.defaultsTo(ent:name);
			ent:threshold := threshold.defaultsTo(ent:threshold);
			ent:phone := phone.defaultsTo(ent:phone);
		}

	}

}