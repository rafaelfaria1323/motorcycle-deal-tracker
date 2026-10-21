import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/platform/share.dart';
import '../../../core/widgets/show_message.dart';

/// Opens the share sheet with [url]; where there is none, copies it.
Future<void> shareOrCopy(
  ScaffoldMessengerState messenger, {
  required String title,
  required String text,
  required String url,
}) async {
  final outcome = await shareLink(title: title, text: text, url: url);
  if (outcome == ShareOutcome.shared) return;
  await Clipboard.setData(ClipboardData(text: '$text $url'));
  showMessage(messenger, 'Link copiado. Cole-o numa mensagem.');
}
