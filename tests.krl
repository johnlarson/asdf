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
				}
			]
		}

	}

	rule temperatures {
		select when test temperatures
		send_directive("temperatures", temperature_store:temperatures())
	}

}