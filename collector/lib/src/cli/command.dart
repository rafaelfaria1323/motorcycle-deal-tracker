import 'dart:io';

import 'package:supabase/supabase.dart';

import '../config/supabase_config.dart';
import '../fetch/polite_fetcher.dart';
import '../notify/telegram_notifier.dart';

/// What a command prints and exits with (sysexits codes) when it stops on
/// [error]; null for anything unexpected, which should crash with its
/// stack trace. The fetch messages are read back by `runStatus` from the
/// run's log ("the site pushed back", "Not fetched: paused until …"):
/// keep their wording.
({String message, int code})? describeFailure(Object error) => switch (error) {
  ConfigException() => (message: 'Configuration error: $error', code: 78),
  FetchBlocked() => (
    message: 'Stopped, the site pushed back: $error',
    code: 75,
  ),
  FetchRefused() => (message: 'Not fetched: $error', code: 75),
  FetchFailed() => (message: 'Failed: $error', code: 75),
  PostgrestException(:final message) => (
    message: 'Database error: $message',
    code: 70,
  ),
  FileSystemException(:final message, :final path) => (
    message: 'Cannot read input: $message ($path)',
    code: 66,
  ),
  FormatException(:final message) => (
    message: 'Invalid input: $message',
    code: 65,
  ),
  NotifyFailed() => (message: 'Not sent: $error', code: 69),
  _ => null,
};

/// Runs [body] with a service-role client from the environment and closes
/// it afterwards. An expected failure ([describeFailure]) is printed and
/// sets the exit code; anything else is rethrown.
Future<void> withServiceClient(
  Future<void> Function(SupabaseClient client) body,
) async {
  SupabaseClient? client;
  try {
    final config = SupabaseConfig.fromEnvironment();
    client = SupabaseClient(config.url, config.serviceKey);
    await body(client);
  } on Object catch (e) {
    final failure = describeFailure(e);
    if (failure == null) rethrow;
    stderr.writeln(failure.message);
    exitCode = failure.code;
  } finally {
    await client?.dispose();
  }
}
