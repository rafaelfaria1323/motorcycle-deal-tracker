"""Fits the Android manifest `flutter create` makes to this app.

deploy-web.yml makes app/android afresh for each build (so it always
matches the runner's Flutter), then runs this on its main manifest:
- the INTERNET permission (the template asks for it only in debug builds,
  so a release could not reach Supabase);
- the name under the icon (the web app's short name);
- no backups (`android:allowBackup="false"`): Android's cloud backup would
  otherwise copy the app's files, the signed-in session among them, to the
  person's Google account. (Android 12+ still copies them phone to phone
  when asked to; the session is encrypted with a Keystore key, which never
  leaves the phone, so the new one just starts signed out.)

Usage: python3 tool/android_manifest.py app/android/app/src/main/AndroidManifest.xml
"""

import re
import sys

LABEL = "Deal Tracker"
INTERNET = '<uses-permission android:name="android.permission.INTERNET"/>'


class ManifestError(Exception):
    pass


def fit_manifest(xml):
    """The manifest with the permission, the label and no backups; fails
    when the template changed so that they can't be placed."""
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
    fitted = re.sub(r'\s*android:allowBackup="[^"]*"', "", fitted)
    fitted = fitted.replace(
        "android:label=", 'android:allowBackup="false"\n        android:label=', 1)
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
