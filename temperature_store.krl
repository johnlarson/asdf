ruleset temperature_store {
	
	meta {
		name "Temperature Store"
	}

	rule collect_temperatures {
		select when wovyn new_temperature_reading
		pre {
			temp = event:attr("temperature").klog("TEMP")
			time = event:attr("timestamp")
		}
		send_directive("hmmm", {})
		fired {
			to_add = {"temperature": temp, "timestamp": time};
			to_add = [to_add].klog("MMM");
			ent:readings := ent:readings.defaultsTo([]).klog("readings");
			ent:readings := ent:readings.append(to_add);
			a = ent:readings.klog("READINGS")
		}
	}

}