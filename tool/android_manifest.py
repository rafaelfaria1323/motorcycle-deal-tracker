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
  leaves the phone, so the new one just starts signed out.);
- with the web app's address, an App Link for it: a shared link
  (https://<host>/#/deals/<id>) opens the app, not the browser, once
  Android has checked the site's /.well-known/assetlinks.json
  (tool/asset_links.py, written by the deploy).

Usage: python3 tool/android_manifest.py app/android/app/src/main/AndroidManifest.xml [web app URL]
"""

import re
import sys
from urllib.parse import urlsplit

LABEL = "Deal Tracker"
INTERNET = '<uses-permission android:name="android.permission.INTERNET"/>'


class ManifestError(Exception):
    pass


def web_host(url):
    """The host of the web app's address; None without one."""
    if not url:
        return None
    parts = urlsplit(url)
    if parts.scheme != "https" or not parts.hostname:
        raise ManifestError(f"not an https address: {url}")
    if not re.fullmatch(r"[a-z0-9.-]+", parts.hostname):
        raise ManifestError(f"unexpected host: {parts.hostname}")
    return parts.hostname


def app_link_filter(host):
    return f"""<intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="https" android:host="{host}"/>
            </intent-filter>
        """


def fit_manifest(xml, host=None):
    """The manifest with the permission, the label, no backups and, with
    [host], the App Link for it; fails when the template changed so that
    they can't be placed."""
    if host and f'android:host="{host}"' not in xml:
        closing = xml.find("</activity>")
        if closing < 0:
            raise ManifestError("no </activity> to put the App Link in")
        xml = xml[:closing] + app_link_filter(host) + xml[closing:]
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
    if len(argv) not in (2, 3):
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2
    with open(argv[1], encoding="utf-8") as f:
        xml = f.read()
    try:
        xml = fit_manifest(xml, web_host(argv[2] if len(argv) == 3 else None))
    except ManifestError as e:
        print(f"{argv[1]}: {e}", file=sys.stderr)
        return 1
    with open(argv[1], "w", encoding="utf-8") as f:
        f.write(xml)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
