$(() => {

	query('sensor_profile', 'profile').then(profile => {
		$('#location').text(profile.location);
		$('#name').text(profile.name);
		$('#threshold').text(profile.threshold);
		$('#phone').text(profile.phone);
		$('#location-form').val(profile.location);
		$('#name-form').val(profile.name);
		$('#threshold-form').val(profile.threshold);
		$('#phone-form').val(profile.phone);
	});

});