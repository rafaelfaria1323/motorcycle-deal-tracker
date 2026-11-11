"""Writes the web app's /.well-known/assetlinks.json: Android reads it to
check that links to the site may open the Android app (App Links; the
manifest's side is tool/android_manifest.py). It names the app's package
and the SHA-256 fingerprint of the key the APK is signed with, both public.

Usage: python3 tool/asset_links.py <SHA-256 fingerprint, AA:BB:...> > assetlinks.json
"""

import json
import re
import sys

# `flutter create --org io.github.rafaelfaria1323` (tool/android_build.sh).
PACKAGE = "io.github.rafaelfaria1323.motorcycle_deal_tracker"


def asset_links(fingerprint):
    """The file's text for the signing key's [fingerprint]."""
    fingerprint = fingerprint.strip().upper()
    if not re.fullmatch(r"[0-9A-F]{2}(:[0-9A-F]{2}){31}", fingerprint):
        raise ValueError("not a SHA-256 fingerprint (32 bytes, AA:BB:...)")
    return json.dumps([{
        "relation": ["delegate_permission/common.handle_all_urls"],
        "target": {
            "namespace": "android_app",
            "package_name": PACKAGE,
            "sha256_cert_fingerprints": [fingerprint],
        },
    }], indent=2) + "\n"


def main(argv):
    if len(argv) != 2:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2
    try:
        sys.stdout.write(asset_links(argv[1]))
    except ValueError as e:
        print(e, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
