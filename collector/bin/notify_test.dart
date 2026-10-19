import 'dart:io';

import 'package:collector/collector.dart';

/// Sends one test message to the owner's Telegram, to check the bot token
/// and chat id without waiting for a real alert.
Future<void> main() async {
  final notifier = TelegramNotifier.fromEnvironment();
  if (notifier == null) {
    stderr.writeln(
      'Telegram not configured: set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID.',
    );
    exitCode = 78;
    return;
  }
  try {
    await notifier.send(
      'Motorcycle Deal Tracker: mensagem de teste. Se a estás a ler, as '
      'notificações chegam a este telemóvel.',
    );
    stdout.writeln('Test message sent.');
  } on NotifyFailed catch (e) {
    // Telegram's own description says what is wrong ("chat not found",
    // "Unauthorized", ...).
    stderr.writeln('Not sent: $e');
    exitCode = 69;
  }
}
