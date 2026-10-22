import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('window.history.state')
external JSAny? get _historyState;

@JS('window.history.back')
external void _back();

/// Flutter's web history tags each entry it adds with `serialCount`
/// (0 = the first one it saw), so above 0 the entry before is the app's.
bool browserBack() {
  final state = _historyState;
  if (state == null || !state.isA<JSObject>()) return false;
  final count = (state as JSObject).getProperty<JSAny?>('serialCount'.toJS);
  if (count == null || !count.isA<JSNumber>()) return false;
  if ((count as JSNumber).toDartDouble <= 0) return false;
  _back();
  return true;
}
