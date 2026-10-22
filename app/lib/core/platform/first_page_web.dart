import 'dart:js_interop';

/// Set by `web/index.html`'s script: a promise of the JSON text, or of
/// null when its requests failed.
@JS('dealTrackerFirstPage')
external JSPromise<JSString?>? get _firstPage;

@JS('dealTrackerFirstPage')
external set _firstPage(JSPromise<JSString?>? value);

Future<String?> takeFirstPage() async {
  final promise = _firstPage;
  if (promise == null) return null;
  _firstPage = null;
  try {
    return (await promise.toDart)?.toDart;
  } on Object {
    return null;
  }
}
