import unittest

import requests


MANAGER_CHANNEL = '7EtK8TRBRYVjYg2BEn3Yeb'


class Pico:

    def __init__(self, id_):
        self.id = id_

    def get(self, func, **attrs):
        ruleset, func = func.split(':')
        url = 'http://localhost:8080/sky/cloud/{}/{}/{}/'
        url = url.format(self.id, ruleset, func)
        return requests.get(url, data=attrs).json()

    def fire(self, event, **attrs):
        domain, event = event.split(':')
        url = 'http://localhost:8080/sky/event/{}/test/{}/{}/'
        url = url.format(self.id, domain, event)
        return requests.get(url, data=attrs).json()


class Tests(unittest.TestCase):

    def setUp(self):
        self.manager = Pico(MANAGER_CHANNEL)

    def test_create_delete(self):
        """Tests sensor create and delete functionality."""
        print(self.manager.get('manage_sensors:sensors'))

    def test_sensor_new_temperature_event(self):
        """
        Sensors created should respond correctly to new temperature events.
        """
        ...

    def test_sensor_profile(self):
        """Sensor profile should get set reliably."""
        ...