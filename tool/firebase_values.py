"""Writes the Android app's Firebase settings as resource strings.

The app's notifications come through Firebase Cloud Messaging, and Firebase
starts itself from these strings (what the google-services Gradle plugin
would write; this needs no plugin). tool/android_build.sh runs this with
the project's google-services.json (GitHub secret FIREBASE_ANDROID_CONFIG)
on stdin; without it the app is built without notifications.

Usage: python3 tool/firebase_values.py <values xml> < google-services.json
"""

import json
import sys
from xml.sax.saxutils import escape

PACKAGE = "io.github.rafaelfaria1323.motorcycle_deal_tracker"


class ConfigError(Exception):
    pass


def firebase_values(config, package=PACKAGE):
    """The strings Firebase reads, from google-services.json's text; fails
    when the file has no Android app with [package]."""
    try:
        data = json.loads(config)
        project = data["project_info"]
        client = next(
            c for c in data["client"]
            if c["client_info"]["android_client_info"]["package_name"] == package
        )
        values = {
            "google_app_id": client["client_info"]["mobilesdk_app_id"],
            "google_api_key": client["api_key"][0]["current_key"],
            "gcm_defaultSenderId": project["project_number"],
            "project_id": project["project_id"],
        }
    except StopIteration:
        raise ConfigError(f"no Android app {package} in google-services.json") from None
    except (ValueError, KeyError, IndexError, TypeError) as e:
        raise ConfigError(f"not a google-services.json ({type(e).__name__}: {e})") from None
    if not all(isinstance(v, str) and v for v in values.values()):
        raise ConfigError("google-services.json has empty values")
    return values


def values_xml(values):
    lines = [f'    <string name="{name}" translatable="false">{escape(value)}</string>'
             for name, value in values.items()]
    return "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<resources>\n" + "\n".join(lines) + "\n</resources>\n"


def main(argv):
    if len(argv) != 2:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2
    try:
        values = firebase_values(sys.stdin.read())
    except ConfigError as e:
        print(f"FIREBASE_ANDROID_CONFIG: {e}", file=sys.stderr)
        return 1
    with open(argv[1], "w", encoding="utf-8") as f:
        f.write(values_xml(values))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
