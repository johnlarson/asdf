ruleset temperature_store {
	
	meta {
		name "Temperature Store"
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

}