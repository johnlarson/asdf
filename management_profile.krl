ruleset management_profile {
	
	meta {
		name "Manage Sensors Profile"
		use module secrets
		use module twilio with
			sid = keys:twilio{"sid"} and
			auth_token = keys:twilio{"auth_token"}
		shares __testing
	}

	global {

		receiver = function() {
			ent:receiver.defaultsTo(secrets:my_number)
		}

		sender = function() {
			ent:sender.defaultsTo(secrets:twilio_number)
		}

		__testing = {
			"events": [
				{
					"domain": "wovyn",
					"type": "threshold_violation",
					"attrs": []
				}
			]
		}

	}

	rule set_receiver {
		select when manager receiver_change
		fired {
			ent:receiver := event:attr("receiver")
		}
	}

	rule set_sender {
		select when manager sender_change
		fired {
			ent:sender := event:attr("sender")
		}
	}

	rule notify_of_threshold_violation {
		select when wovyn threshold_violation
		twilio:send(receiver(), sender(), "Too hot (Manager)!")
	}

}