import json
import unittest

import requests


with open('secrets.json', 'r') as secrets_file:
    secrets = json.load(secrets_file)
    ROOT_CHANNEL = secrets['testing_channel']


class Pico:

    def __init__(self, channel):
        self.channel = channel

    def get(self, func, **attrs):
        ruleset, func = func.split(':')
        url = 'http://localhost:8080/sky/cloud/{}/{}/{}/'
        url = url.format(self.channel, ruleset, func)
        return requests.get(url, data=attrs).json()

    def fire(self, event, **attrs):
        domain, event = event.split(':')
        url = 'http://localhost:8080/sky/event/{}/test/{}/{}/'
        url = url.format(self.channel, domain, event)
        return requests.get(url, data=attrs).json()


class Tests(unittest.TestCase):

    def setUp(self):
        self.root = Pico(ROOT_CHANNEL)
        r = self.root.fire('wrangler:child_creation', name='test_manager')
        self.manager = Pico(r['directives'][0]['options']['pico']['eci'])
        self.manager.fire('wrangler:install_rulesets_requested',
                          rids='manage_sensors')

    def tearDown(self):
        self.root.fire('wrangler:child_deletion', name='test_manager')

    def test_create_delete(self):
        """Tests sensor create and delete functionality."""
        #self.manager.fire('sensor:new_sensor', name='a')
        #print(self.manager.get('manage_sensors:sensors'))
        ...

    def test_sensor_new_temperature_event(self):
        """
        Sensors created should respond correctly to new temperature events.
        """
        ...

    def test_sensor_profile(self):
        """Sensor profile should get set reliably."""
        ...