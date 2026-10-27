import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/localizations.dart';

/// Shows a plain text message in a snack bar, so every one looks the same.
void showMessage(ScaffoldMessengerState messenger, String text) {
  messenger.showSnackBar(SnackBar(content: Text(text)));
}

/// Copies a message to send to a seller and says so; where the browser
/// refuses the clipboard, asks to select the text instead.
Future<void> copyMessage(BuildContext context, String text) async {
  final strings = context.strings;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await Clipboard.setData(ClipboardData(text: text));
    showMessage(messenger, strings.messageCopied);
  } catch (_) {
    showMessage(messenger, strings.couldNotCopySelectTextInstead);
  }
}
