import json
import unittest
from time import sleep

import requests


with open('secrets.json', 'r') as secrets_file:
    secrets = json.load(secrets_file)


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
        self.root = Pico(secrets['testing_channel'])
        r = self.root.fire('wrangler:child_creation', name='test_manager')
        self.manager = Pico(r['directives'][0]['options']['pico']['eci'])
        self.manager.fire('wrangler:install_rulesets_requested',
                          rids='manage_sensors')

    def tearDown(self):
        self.root.fire('wrangler:child_deletion', name='test_manager')
        sleep(0.1)

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
        self.manager.fire('sensor:new_sensor', name='a')
        channel = self.manager.get('manage_sensors:sensors')['a']['eci']
        sensor = Pico(channel)
        self.assertEqual(sensor.get('temperature_store:temperatures'), [])
        thr_violations = sensor.get('temperature_store:threshold_violations')
        self.assertEqual(thr_violations, [])
        sensor.fire('wovyn:fake_heartbeat', temperature=80)
        sensor.fire('wovyn:fake_heartbeat', temperature=120)
        temps = sensor.get('temperature_store:temperatures')
        temps = [temp['temperature'] for temp in temps]
        violations = sensor.get('temperature_store:threshold_violations')
        violations = [v['temperature'] for v in violations]
        self.assertEqual(temps, ['80', '120'])
        self.assertEqual(violations, ['120'])

    def test_sensor_profile(self):
        """Sensor profile should get set reliably."""
        self.manager.fire('sensor:new_sensor', name='a')
        channel = self.manager.get('manage_sensors:sensors')['a']['eci']
        sensor = Pico(channel)
        exp_start = {
            'location': None,
            'name': 'a',
            'threshold': 100,
            'phone': secrets['phone_number'],
        }
        self.assertEqual(sensor.get('sensor_profile:profile'), exp_start)
        sensor.fire('sensor:profile_updated', location='a', name='b',
                    threshold=70, phone='c')
        exp_end = {
            'location': 'a',
            'name': 'b',
            'threshold': 70,
            'phone': 'c',
        }
        self.assertEqual(sensor.get('sensor_profile:profile'), exp_end)
