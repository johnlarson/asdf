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
			ent:readings := {"temperature": temp, "timestamp": time};
			a = event:attr("temperature").klog("AGAIN");
			a = ent:readings.klog("READINGS")
		}
	}

}