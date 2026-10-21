import 'dart:js_interop';

import 'share.dart';

@JS('navigator.share')
external JSFunction? get _shareFunction;

@JS('navigator.share')
external JSPromise<JSAny?> _share(JSObject data);

Future<ShareOutcome> shareLink({
  required String title,
  required String text,
  required String url,
}) async {
  if (_shareFunction == null) return ShareOutcome.unavailable;
  try {
    await _share(
      {'title': title, 'text': text, 'url': url}.jsify()! as JSObject,
    ).toDart;
    return ShareOutcome.shared;
  } on Object catch (e) {
    // Closing the sheet without choosing is an AbortError: nothing to do.
    return e.toString().contains('AbortError')
        ? ShareOutcome.shared
        : ShareOutcome.unavailable;
  }
}
