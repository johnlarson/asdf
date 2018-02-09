function query(ruleset, name, args = {}) {
	const url = `http://localhost:8080/sky/cloud/JmspudNCA3yuqKsGjWW7ky/${ruleset}/${name}/`;
	return $.ajax({
		url: url,
	});
}

function action(domain, name, args = {}) {
	const url = `http://localhost:8080/sky/event/JmspudNCA3yuqKsGjWW7ky/null/${domain}/${name}/`;
}