ruleset sky {

	meta {
		name "Sky"
		provides query
	}

	global {
		query = function(eci, mod, func, params) {
			base_url = "http://localhost:8080/sky/cloud/";
			url = base_url + eci + "/" + mod + "/" + func;
			params = params.defaultsTo({}).put(["_eci"], eci);
			response = http:get(url, params);
			response{"content"}.decode()
		};
	}
		

}