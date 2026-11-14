import 'package:flutter/services.dart';

const _channel = MethodChannel('deal_tracker/shared_text');

/// The Android app: the in-repo plugin packages/share_receiver hands over
/// the text of an ACTION_SEND intent, once each.
Future<void> listenToSharedText(void Function(String text) open) async {
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'shared' && call.arguments is String) {
      open(call.arguments as String);
    }
  });
  try {
    final text = await _channel.invokeMethod<String>('initialText');
    if (text != null) open(text);
  } on PlatformException {
    // No shared text to open.
  } on MissingPluginException {
    // Not the Android app (tests, desktop).
  }
}
