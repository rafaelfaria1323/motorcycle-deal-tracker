"""Tests for tool/asset_links.py: python3 -m unittest discover -s tool -p 'test_*.py'"""

import json
import os
import re
import unittest

from asset_links import PACKAGE, asset_links

FINGERPRINT = ":".join(f"{i:02X}" for i in range(32))


class AssetLinksTest(unittest.TestCase):
    def test_names_the_package_and_the_key(self):
        links = json.loads(asset_links(FINGERPRINT.lower() + "\n"))
        self.assertEqual(len(links), 1)
        self.assertEqual(
            links[0]["relation"], ["delegate_permission/common.handle_all_urls"])
        self.assertEqual(links[0]["target"], {
            "namespace": "android_app",
            "package_name": PACKAGE,
            "sha256_cert_fingerprints": [FINGERPRINT],
        })

    def test_anything_else_is_refused(self):
        for bad in ("", "AA:BB", FINGERPRINT + ":00", FINGERPRINT.replace(":", "")):
            with self.assertRaises(ValueError):
                asset_links(bad)

    def test_the_package_is_the_one_the_build_makes(self):
        here = os.path.dirname(__file__)
        with open(os.path.join(here, "android_build.sh"), encoding="utf-8") as f:
            build = f.read()
        org = re.search(r"--org (\S+)", build).group(1)
        name = re.search(r"--project-name (\S+)", build).group(1)
        self.assertEqual(PACKAGE, f"{org}.{name}")


if __name__ == "__main__":
    unittest.main()
