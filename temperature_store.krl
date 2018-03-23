ruleset temperature_store {
	
	meta {
		name "Temperature Store"
		provides temperatures, threshold_violations, inrange_temperatures
		shares temperatures, threshold_violations, inrange_temperatures, __testing
	}

	global {

		temperatures = function() {
			ent:readings.defaultsTo([])
		}

		threshold_violations = function() {
			ent:threshold_violations.defaultsTo([])
		}

		inrange_temperatures = function() {
			v = threshold_violations();
			temperatures().filter(function(x) { not(v >< x) })
		}

		__testing = {
			"queries": [
				{
					"name": "temperatures",
					"args": []
				},
				{
					"name": "threshold_violations",
					"args": []
				},
				{
					"name": "inrange_temperatures",
					"args": []
				}
			]
		}

	}

	rule collect_temperatures {
		select when wovyn new_temperature_reading
		pre {
			temp = event:attr("temperature")
			time = event:attr("timestamp")
			to_add = [{"temperature": temp, "timestamp": time}];
		}
		fired {
			ent:readings := ent:readings.defaultsTo([]);
			ent:readings := ent:readings.append(to_add)
		}
	}

	rule collect_threshold_violations {
		select when wovyn threshold_violation
		pre {
			temp = event:attr("temperature")
			time = event:attr("timestamp")
			to_add = [{"temperature": temp, "timestamp": time}];
		}
		fired {
			ent:threshold_violations := ent:threshold_violations.defaultsTo([]);
			ent:threshold_violations := ent:threshold_violations.append(to_add)
		}
	}

	rule clear_temperatures {
		select when sensor reading_reset
		fired {
			ent:readings := [];
			ent:threshold_violations := []
		}
	}

	rule temperature_report {
		select when sensor temp_report_needed
		event:send({
			"eci": event:attr("Tx"),
			"host": event:attr("Tx_host"),
			"domain": "sensor",
			"type": "temp_report_generated",
			"attrs": {
				"cid": event:attr("cid"),
				"temperatures": temperatures(),
				"Tx": event:attr("Rx"),
				"Tx_host": meta:host
			}
		})
		fired {
			event:attrs.klog("TEMPERATURE_STORE:TEMPERATURE_REPORT ATTRS:")
		}
	}

}