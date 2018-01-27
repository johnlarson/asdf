ruleset twilio {
	meta {
		name "Twilio"
		description << Twilio client library. >>
		configure using sid = ""
		                auth_token = ""
		provides
			send, messages
	}

	global {

		send = defaction(to, from, msg) {
			base_url = <<https://#{sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{sid}/>>
			http:post(base_url + "Messages.json", form = {
					"From":from,
					"To":to,
					"Body":msg
				})
		}

		messages = function(page_size, to, from) {
			url = <<https://#{sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{sid}/Messages.json>>;
			q = {};
			q = page_size => q.put({"PageSize": page_size}) | q;
			q = to => q.put({"To": to}) | q;
			q = from => q.put({"From": from}) | q;
			response = http:get(url, qs = q);
			response["content"].decode()
		}
	}
}