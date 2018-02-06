ruleset tests {
	
	meta {
		name "Tests"
		use module temperature_store
		shares __testing
	}

	global {

		__testing = {
			"events": [
				{
					"domain": "test",
					"type": "temperatures",
					"attrs": []
				},
				{
					"domain": "test",
					"type": "threshold_violations",
					"attrs": []
				},
				{
					"domain": "test",
					"type": "inrange",
					"attrs": []
				}
			]
		}

	}

	rule temperatures {
		select when test temperatures
		send_directive("temperatures", {"readings": temperature_store:temperatures()})
	}

	rule threshold_violations {
		select when test threshold_violations
		send_directive("threshold_violations", {"violations": temperature_store:threshold_violations()})
	}

	rule inrange_temperatures {
		select when test inrange
		send_directive("inrange", {"inrange": temperature_store:inrange_temperatures()})
	}

}