ruleset sky {

	meta {
		name "Sky"
		provides query
	}

	global {
		query = function(host, eci, mode, func, params) {
			host = host.defaultsTo("http://localhost:8080/sky/cloud/");
			url = base_url + eci + "/" + mode + "/" + func;
			params = params.defaultsTo({}).put(["_eci"], eci);
			response = http:get(url, params);
			response{"content"}.decode()
		};
	}
		

}