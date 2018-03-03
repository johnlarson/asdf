import json
import unittest
from time import sleep

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
        print(r['directives'][0]['options'])
        self.manager = Pico(r['directives'][0]['options']['pico']['eci'])
        self.manager.fire('wrangler:install_rulesets_requested',
                          rids='manage_sensors')

    def tearDown(self):
        self.root.fire('wrangler:child_deletion', name='test_manager')
        sleep(0.01)

    def test_create_delete(self):
        """Tests sensor create and delete functionality."""
        self.assertEqual(self.manager.get('manage_sensors:sensors'), {})
        self.manager.fire('sensor:new_sensor', name='a')
        self.manager.fire('sensor:new_sensor', name='b')
        self.manager.fire('sensor:new_sensor', name='c')
        sensors = self.manager.get('manage_sensors:sensors')
        keys = sensors.keys()
        self.assertIn('a', keys)
        self.assertIn('b', keys)
        self.assertIn('c', keys)
        a = sensors['a']
        self.assertIn('eci', a.keys())
        self.assertTrue(isinstance(a['eci'], str))
        self.manager.fire('sensor:unneeded_sensor', name='b')
        keys = self.manager.get('manage_sensors:sensors').keys()
        self.assertIn('a', keys)
        self.assertNotIn('b', keys)
        self.assertIn('c', keys)

    def test_sensor_new_temperature_event(self):
        """
        Sensors created should respond correctly to new temperature events.
        """
        ...

    def test_sensor_profile(self):
        """Sensor profile should get set reliably."""
        ...