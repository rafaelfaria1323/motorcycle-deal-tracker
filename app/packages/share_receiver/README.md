# share_receiver

The Android app as a share target (N.103): Share › Deal Tracker in the
OLX or Standvirtual app opens "Avaliar um anúncio" with the ad's link
filled in. Android only, no Dart code: `lib/core/platform/shared_text_stub.dart`
calls the channel `deal_tracker/shared_text`.

- `initialText`: the text of the `ACTION_SEND` (`text/plain`) intent the
  app was started with, or null; taken once (the intent becomes a plain
  launch, so a restart doesn't open it again).
- `shared` (plugin to app): the text of each share while the app runs
  (`onNewIntent`; other intents are left to the other plugins).

The intent-filter is on the app's MainActivity, added by
`tool/android_manifest.py` (`app/android` is made by `flutter create` at
each build). The app reads only the link in the text (`adLinkOf`); no ad
page is ever fetched.
