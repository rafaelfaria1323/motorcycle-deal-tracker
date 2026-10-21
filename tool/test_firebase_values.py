"""Tests for tool/firebase_values.py: python3 -m unittest discover -s tool -p 'test_*.py'"""

import json
import unittest

from firebase_values import PACKAGE, ConfigError, firebase_values, values_xml


def config(package=PACKAGE):
    """The shape of a google-services.json (made-up values)."""
    return json.dumps({
        "project_info": {"project_number": "123456789012", "project_id": "deal-tracker"},
        "client": [
            {
                "client_info": {
                    "mobilesdk_app_id": "1:123456789012:android:other",
                    "android_client_info": {"package_name": "com.example.other"},
                },
                "api_key": [{"current_key": "other-key"}],
            },
            {
                "client_info": {
                    "mobilesdk_app_id": "1:123456789012:android:abc",
                    "android_client_info": {"package_name": package},
                },
                "api_key": [{"current_key": "AIza-test&key"}],
            },
        ],
    })


class FirebaseValuesTest(unittest.TestCase):
    def test_reads_our_app(self):
        self.assertEqual(firebase_values(config()), {
            "google_app_id": "1:123456789012:android:abc",
            "google_api_key": "AIza-test&key",
            "gcm_defaultSenderId": "123456789012",
            "project_id": "deal-tracker",
        })

    def test_the_xml_escapes_values(self):
        xml = values_xml(firebase_values(config()))
        self.assertIn('<string name="google_api_key" translatable="false">AIza-test&amp;key</string>', xml)
        self.assertTrue(xml.startswith("<?xml"))

    def test_a_file_without_our_app_or_broken_fails(self):
        with self.assertRaisesRegex(ConfigError, "no Android app"):
            firebase_values(config("com.example.wrong"))
        for text in ["", "{}", "[]", '{"project_info": {}, "client": []}']:
            with self.assertRaises(ConfigError):
                firebase_values(text)


if __name__ == "__main__":
    unittest.main()
