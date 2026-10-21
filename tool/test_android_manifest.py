"""Tests for tool/android_manifest.py: python3 -m unittest discover -s tool -p 'test_*.py'"""

import unittest

from android_manifest import ManifestError, fit_manifest

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
        self.assertNotIn("motorcycle_deal_tracker", xml)
        self.assertIn('android:icon="@mipmap/ic_launcher"', xml)

    def test_running_twice_changes_nothing_more(self):
        once = fit_manifest(TEMPLATE)
        self.assertEqual(fit_manifest(once), once)
        self.assertEqual(once.count("INTERNET"), 1)

    def test_a_changed_template_fails_loudly(self):
        with self.assertRaises(ManifestError):
            fit_manifest("<foo/>")
        with self.assertRaises(ManifestError):
            fit_manifest(TEMPLATE.replace('android:label="motorcycle_deal_tracker"', ""))


if __name__ == "__main__":
    unittest.main()
