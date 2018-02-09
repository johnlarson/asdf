"use strict";

updateLoop();

function updateLoop() {
	console.log('Update.');
	update();
	setTimeout(updateLoop, 2000);
}

function update() {
	Promise.all([getTemperatures(), getViolations()]).then(([temps, violations]) => {
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
	$('#current-temp').text(`${temp} °F`);
}

function updateTempsList(temps, violations) {
	const violationTimes = new Set();
	for(let violation of violations) {
		violationTimes.add(violation.timestamp);
	}
	$('#log-list').empty();
	for(let temp of temps) {
		const tooHot = violationTimes.has(temp.timestamp);
		const cls = tooHot ? 'violation' : '';
		const item = $(`<li class="${cls}">${temp.timestamp} -- ${temp.temperature} °F</li>`);
		$('#log-list').append(item);
	}
}