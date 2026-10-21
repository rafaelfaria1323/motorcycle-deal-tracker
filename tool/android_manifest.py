"""Fits the Android manifest `flutter create` makes to this app.

deploy-web.yml makes app/android afresh for each build (so it always
matches the runner's Flutter), then runs this on its main manifest:
- the INTERNET permission (the template asks for it only in debug builds,
  so a release could not reach Supabase);
- the name under the icon (the web app's short name).

Usage: python3 tool/android_manifest.py app/android/app/src/main/AndroidManifest.xml
"""

import re
import sys

LABEL = "Deal Tracker"
INTERNET = '<uses-permission android:name="android.permission.INTERNET"/>'


class ManifestError(Exception):
    pass


def fit_manifest(xml):
    """The manifest with the permission and the label; fails when the
    template changed so that neither can be placed."""
    if "android.permission.INTERNET" not in xml:
        opening = re.search(r"<manifest\b[^>]*>", xml)
        if opening is None:
            raise ManifestError("no <manifest> element")
        xml = (xml[:opening.end()] + "\n    " + INTERNET
               + xml[opening.end():])
    application = re.search(r"<application\b[^>]*>", xml)
    if application is None:
        raise ManifestError("no <application> element")
    tag = application.group(0)
    if "android:label=" not in tag:
        raise ManifestError("<application> has no android:label")
    fitted = re.sub(r'android:label="[^"]*"', f'android:label="{LABEL}"', tag)
    return xml[:application.start()] + fitted + xml[application.end():]


def main(argv):
    if len(argv) != 2:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2
    with open(argv[1], encoding="utf-8") as f:
        xml = f.read()
    try:
        xml = fit_manifest(xml)
    except ManifestError as e:
        print(f"{argv[1]}: {e}", file=sys.stderr)
        return 1
    with open(argv[1], "w", encoding="utf-8") as f:
        f.write(xml)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
