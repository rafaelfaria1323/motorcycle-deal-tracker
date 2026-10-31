import 'dart:io';

import 'package:args/args.dart';
import 'package:supabase/supabase.dart';

import '../config/supabase_config.dart';
import '../fetch/polite_fetcher.dart';

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

/// [args] read by [parser] (package `args`), or null when the command
/// should stop: `--help` prints [usage] and the options to [out]; an
/// unknown or malformed option, a number in [atLeast] below its minimum
/// (`--max=0`) or a count of plain arguments other than [positional]
/// prints the problem, [usage] and the options to [err] and sets exit
/// code 64 (sysexits' usage error).
ArgResults? readCommandLine(
  ArgParser parser,
  List<String> args, {
  required String usage,
  int positional = 0,
  Map<String, int> atLeast = const {},
  StringSink? out,
  StringSink? err,
}) {
  parser.addFlag('help', abbr: 'h', negatable: false, help: 'This text.');
  String? problem;
  try {
    final results = parser.parse(args);
    if (results.flag('help')) {
      (out ?? stdout)
        ..writeln(usage)
        ..writeln(parser.usage);
      return null;
    }
    problem = _numberProblem(results, atLeast);
    if (problem == null && results.rest.length != positional) {
      problem = positional == 0
          ? 'Unexpected argument: ${results.rest.first}'
          : 'Expected $positional argument(s), got ${results.rest.length}';
    }
    if (problem == null) return results;
  } on ArgParserException catch (e) {
    problem = e.message;
  }
  (err ?? stderr)
    ..writeln(problem)
    ..writeln(usage)
    ..writeln(parser.usage);
  exitCode = 64;
  return null;
}

String? _numberProblem(ArgResults results, Map<String, int> atLeast) {
  for (final MapEntry(key: name, value: min) in atLeast.entries) {
    final text = results.option(name);
    if (text == null) continue;
    final value = int.tryParse(text);
    if (value == null || value < min) {
      return '--$name must be a whole number of at least $min (got "$text")';
    }
  }
  return null;
}

/// Option [name] as a number ([readCommandLine]'s `atLeast` checked it),
/// or null when it wasn't given.
int? intOption(ArgResults results, String name) =>
    switch (results.option(name)) {
      final String text => int.parse(text),
      null => null,
    };
