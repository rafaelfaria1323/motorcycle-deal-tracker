# file_share

The Android app's share sheet for a file the app made: the ad's report as
a PDF (N.127). Android only, no Dart code: `lib/core/platform/share_file_stub.dart`
calls the channel `deal_tracker/file_share` (method `share`: `bytes`,
`name`, a plain file name, `type`, the MIME type, and `title`).

The plugin writes the file to the cache's `shared/` folder (the only one
its `FileShareProvider` exposes; each share replaces the last) and opens
Android's chooser with `Intent.ACTION_SEND`, `EXTRA_STREAM` and a
read-only grant to the app the person picks. No permission. Without an
app to take it, it answers `false` and the app shares the report as text.

The web app shares the same file through `navigator.share` where the
browser can share files, else downloads it (`share_file_web.dart`).
