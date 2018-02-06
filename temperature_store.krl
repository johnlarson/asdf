ruleset temperature_store {
	
	meta {
		name "Temperature Store"
		provides temperatures, threshold_violations, inrange_temperatures
	}

	global {

		temperatures = function() {
			ent:readings
		}

		threshold_violations = function() {
			ent:threshold_violations
		}

		inrange_temperatures = function() {
			v = threshold_violations();
			temperatures().filter(function(x) { not(v >< x) })
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

}