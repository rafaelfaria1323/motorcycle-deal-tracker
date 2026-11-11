"""Tests for tool/android_manifest.py: python3 -m unittest discover -s tool -p 'test_*.py'"""

import unittest

from android_manifest import ManifestError, fit_manifest, web_host

# The start of the manifest `flutter create` makes.
TEMPLATE = """<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="motorcycle_deal_tracker"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity android:name=".MainActivity" android:exported="true"/>
    </application>
</manifest>
"""


class FitManifestTest(unittest.TestCase):
    def test_adds_internet_and_the_label(self):
        xml = fit_manifest(TEMPLATE)
        self.assertIn('<uses-permission android:name="android.permission.INTERNET"/>', xml)
        self.assertLess(xml.index("INTERNET"), xml.index("<application"))
        self.assertIn('android:label="Deal Tracker"', xml)
        self.assertEqual(xml.count('android:allowBackup="false"'), 1)
        self.assertNotIn("motorcycle_deal_tracker", xml)
        self.assertIn('android:icon="@mipmap/ic_launcher"', xml)

    def test_running_twice_changes_nothing_more(self):
        once = fit_manifest(TEMPLATE)
        self.assertEqual(fit_manifest(once), once)
        self.assertEqual(once.count("INTERNET"), 1)

    def test_a_template_that_allows_backups_no_longer_does(self):
        xml = fit_manifest(TEMPLATE.replace(
            "<application", '<application android:allowBackup="true"'))
        self.assertNotIn('allowBackup="true"', xml)
        self.assertEqual(xml.count('android:allowBackup="false"'), 1)

    def test_a_changed_template_fails_loudly(self):
        with self.assertRaises(ManifestError):
            fit_manifest("<foo/>")
        with self.assertRaises(ManifestError):
            fit_manifest(TEMPLATE.replace('android:label="motorcycle_deal_tracker"', ""))

    def test_the_web_address_becomes_an_app_link(self):
        template = TEMPLATE.replace(
            'android:exported="true"/>',
            'android:exported="true">\n            <intent-filter>\n'
            '                <action android:name="android.intent.action.MAIN"/>\n'
            '            </intent-filter>\n        </activity>')
        xml = fit_manifest(template, "deal.example.pages.dev")
        self.assertIn('<intent-filter android:autoVerify="true">', xml)
        self.assertIn(
            '<data android:scheme="https" android:host="deal.example.pages.dev"/>', xml)
        self.assertIn("android.intent.action.VIEW", xml)
        self.assertIn("android.intent.category.BROWSABLE", xml)
        # Inside the activity, after its launcher filter.
        self.assertLess(xml.index("action.MAIN"), xml.index("action.VIEW"))
        self.assertLess(xml.index("action.VIEW"), xml.index("</activity>"))
        self.assertEqual(fit_manifest(xml, "deal.example.pages.dev"), xml)
        # Without an address the manifest has no link.
        self.assertNotIn("autoVerify", fit_manifest(template))
        with self.assertRaises(ManifestError):
            fit_manifest(TEMPLATE, "deal.example.pages.dev")

    def test_only_an_https_host_is_taken(self):
        self.assertEqual(web_host("https://deal.example.pages.dev"), "deal.example.pages.dev")
        self.assertEqual(web_host("https://Deal.Example.dev/path#/x"), "deal.example.dev")
        self.assertIsNone(web_host(""))
        self.assertIsNone(web_host(None))
        for bad in ("http://deal.example.dev", "deal.example.dev", 'https://a"b.dev'):
            with self.assertRaises(ManifestError):
                web_host(bad)


if __name__ == "__main__":
    unittest.main()
