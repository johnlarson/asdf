"use strict";


update()


function update() {
	Promise.all([getTemperatures(), getViolations()]).then(([temps, violations]) => {
		console.log('temps:', temps);
		console.log('violations:', violations)
		updateCurrentTemp(temps[temps.length - 1].temperature);
		updateTempsList(temps, violations);
	});
}

function getTemperatures() {
	return query('temperature_store', 'temperatures');
}

function getViolations() {
	return query('temperature_store', 'threshold_violations');
}

function updateCurrentTemp(temp) {

}

function updateTempsList(temps, violations) {

}

function query(ruleset, name, args = {}) {
	const url = `http://localhost:8080/sky/cloud/JmspudNCA3yuqKsGjWW7ky/${ruleset}/${name}/`;
	console.log('url:', url)
	return $.ajax({
		url: url,
	});
}

function action(domain, name, args = {}) {
	const url = `http://localhost:8080/sky/event/JmspudNCA3yuqKsGjWW7ky/null/${domain}/${name}/`;
}