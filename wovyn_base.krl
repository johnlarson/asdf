ruleset wovyn_base {
	
	meta {
		name "Wovyn Base"
		shares __testing
	}

	global {
		__testing = {
			"events": [
				{
					"domain": "wovyn",
					"type": "heartbeat",
					"attrs": []
				}
			]
		}
	}

	rule process_heartbeat {
		select when wovyn heartbeat
		pre {
			data = event:attr("data").decode().klog()
		}
		send_directive("heartbeat", data)
	}

}