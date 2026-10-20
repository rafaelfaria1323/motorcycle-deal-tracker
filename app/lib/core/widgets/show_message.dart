import 'package:flutter/material.dart';

/// Shows a plain text message in a snack bar, so every one looks the same.
void showMessage(ScaffoldMessengerState messenger, String text) {
  messenger.showSnackBar(SnackBar(content: Text(text)));
}
