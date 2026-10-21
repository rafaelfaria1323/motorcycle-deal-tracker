# android_push

The Android app's notifications (Deal Tracker only): registers with
Firebase Cloud Messaging, shows each message the collector sends as a
notification (channel "Alertas") and opens its page on a tap. Firebase
starts from the resource strings `tool/firebase_values.py` writes into the
app at build time; without them the app reports no notifications.

Channel `deal_tracker/android_push` (called by
`lib/core/platform/push_stub.dart`): `state`, `enable` (asks for the
permission, returns the registration token), `disable`, `initialUrl`; the
plugin calls `open` with the page of a notification tapped while the app
runs.
