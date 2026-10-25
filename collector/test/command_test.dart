import 'dart:convert';
import 'dart:io';

import 'package:collector/collector.dart';
import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

const _manualListing = {
  'url': 'https://example.com/a',
  'brand': 'Yamaha',
  'model': 'MT-07',
  'price_eur': 6500,
  'year': 2021,
  'seller_type': 'private',
};

Future<({int code, String log, int stored})> _import({
  required bool dryRun,
  bool unreadable = true,
}) async {
  final directory = await Directory.systemTemp.createTemp('collector-command-');
  final input = File('${directory.path}/input.json');
  await input.writeAsString(jsonEncode([_manualListing, if (unreadable) 42]));
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  var stored = 0;
  server.listen((request) async {
    final body = await utf8.decoder.bind(request).join();
    final Object response;
    switch (request.uri.path) {
      case '/rest/v1/motorcycles':
      case '/rest/v1/rpc/push_keys':
      case '/rest/v1/rpc/pending_notifications':
        response = <Object>[];
      case '/rest/v1/listings':
        final rows = jsonDecode(body) as List<dynamic>;
        stored += rows.length;
        response = [
          for (var i = 0; i < rows.length; i++) {'id': 'listing-$i'},
        ];
      default:
        expect(request.uri.path, startsWith('/rest/v1/rpc/'));
        response = 0;
    }
    request.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(response));
    await request.response.close();
  });
  Process? process;
  try {
    process = await Process.start(
      Platform.resolvedExecutable,
      [
        '--packages=${Directory.current.path}/.dart_tool/package_config.json',
        'bin/collector.dart',
        'manual',
        input.path,
        if (dryRun) '--dry-run',
      ],
      environment: {
        'SUPABASE_URL': 'http://127.0.0.1:${server.port}',
        'SUPABASE_SERVICE_ROLE_KEY': 'test-only-key',
      },
      includeParentEnvironment: false,
    );
    await process.stdin.close();
    final output = utf8.decoder.bind(process.stdout).join();
    final errors = utf8.decoder.bind(process.stderr).join();
    final code = await process.exitCode.timeout(const Duration(seconds: 15));
    return (code: code, log: '${await output}${await errors}', stored: stored);
  } finally {
    if (process != null) {
      process.kill();
      await process.exitCode;
    }
    await server.close(force: true);
    await directory.delete(recursive: true);
  }
}

void main() {
  test('each expected failure has its message and exit code', () {
    final cases = <Object, (String, int)>{
      ConfigException('SUPABASE_URL is not set'): ('Configuration error: ', 78),
      const FetchBlocked('HTTP 429'): ('Stopped, the site pushed back: ', 75),
      const FetchLimitReached('20 requests this run'): ('Not fetched: ', 75),
      const FetchRefused('paused until 2026-10-21'): ('Not fetched: ', 75),
      const FetchFailed('HTTP 500'): ('Failed: ', 75),
      const PostgrestException(message: 'timeout'): (
        'Database error: timeout',
        70,
      ),
      const FileSystemException('Folder not found', 'pages'): (
        'Cannot read input: Folder not found (pages)',
        66,
      ),
      const FormatException('bad JSON'): ('Invalid input: bad JSON', 65),
      const NotifyFailed('HTTP 502'): ('Not sent: ', 69),
    };
    for (final MapEntry(key: error, value: (prefix, code)) in cases.entries) {
      final failure = describeFailure(error);
      expect(failure?.message, startsWith(prefix), reason: '$error');
      expect(failure?.code, code, reason: '$error');
    }
  });

  test('the wording runStatus reads in the log is kept', () {
    final blocked = describeFailure(const FetchBlocked('HTTP 429'))!;
    expect(runStatus(75, blocked.message), 'blocked');
  });

  test('anything unexpected is not described, so it crashes loudly', () {
    expect(describeFailure(StateError('bug')), isNull);
    expect(describeFailure(ArgumentError('bug')), isNull);
  });

  test(
    'a partial import saves readable records but exits with an error',
    () async {
      final result = await _import(dryRun: false);

      expect(result.stored, 1);
      expect(result.log, contains('1 read issue(s)'));
      expect(result.code, 65);
      expect(runProblems(result.log).single, startsWith('Read issue: '));
      expect(result.log, contains('Scored 0 listing(s).'));
      expect(result.log, contains('Alerts created: 0'));
    },
  );

  test('a partial dry run fails without writing anything', () async {
    final result = await _import(dryRun: true);

    expect(result.stored, 0);
    expect(result.log, contains('Dry run: nothing was written.'));
    expect(result.code, 65);
  });

  test('a clean dry run still succeeds', () async {
    final result = await _import(dryRun: true, unreadable: false);

    expect(result.stored, 0);
    expect(result.code, 0, reason: result.log);
  });
}
