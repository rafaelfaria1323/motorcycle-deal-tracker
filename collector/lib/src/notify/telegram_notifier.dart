import 'dart:async';
import 'dart:convert';
import 'dart:io';

class NotifyFailed implements Exception {
  const NotifyFailed(this.reason);

  final String reason;

  @override
  String toString() => reason;
}

class TelegramNotifier {
  TelegramNotifier({required this.token, required this.chatId});

  /// Null when TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID is not set: then
  /// nothing is pushed and the run is otherwise unchanged.
  static TelegramNotifier? fromEnvironment() {
    final token = Platform.environment['TELEGRAM_BOT_TOKEN'];
    final chatId = Platform.environment['TELEGRAM_CHAT_ID'];
    if (token == null || token.isEmpty || chatId == null || chatId.isEmpty) {
      return null;
    }
    return TelegramNotifier(token: token, chatId: chatId);
  }

  final String token;
  final String chatId;

  Future<void> send(String text) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client
          .postUrl(Uri.https('api.telegram.org', '/bot$token/sendMessage'))
          .timeout(const Duration(seconds: 15));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'chat_id': chatId, 'text': text}));
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        // The body is Telegram's error description; it never contains the token.
        throw NotifyFailed('Telegram HTTP ${response.statusCode}: $body');
      }
    } on TimeoutException {
      throw const NotifyFailed('Telegram timed out');
    } on SocketException catch (e) {
      throw NotifyFailed('Telegram unreachable: ${e.message}');
    } finally {
      client.close(force: true);
    }
  }
}
