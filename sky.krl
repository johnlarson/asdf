ruleset sky {

	meta {
		name "Sky"
		provides query
	}

	global {
		query = function(host, eci, rid, func, params) {
			host = host.defaultsTo("http://localhost:8080");
			url = host + "/sky/cloud/" + eci + "/" + rid + "/" + func;
			url.klog("URL");
			params = params.defaultsTo({}).put(["_eci"], eci);
			response = http:get(url, params);
			response{"content"}.decode()
		};
	}
		

}