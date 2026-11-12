import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:collector/collector.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
      case '/rest/v1/rpc/pending_visit_reminders':
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

  group('the database client asks once more', () {
    Future<({int status, int asked, String log})> ask(
      List<Object> answers,
    ) async {
      var asked = 0;
      final log = StringBuffer();
      final client = retryingClient(
        MockClient((_) async {
          final answer = answers[asked++];
          if (answer is Exception) throw answer;
          return http.Response('', answer as int);
        }),
        delay: Duration.zero,
        out: log,
      );
      try {
        final response = await client.post(
          Uri.parse('https://db.example/rest/v1/rpc/mark_duplicates'),
        );
        return (status: response.statusCode, asked: asked, log: '$log');
      } finally {
        client.close();
      }
    }

    test('after a lost connection or a gateway error', () async {
      for (final first in <Object>[
        const SocketException('reset'),
        http.ClientException('closed'),
        502,
        503,
        504,
      ]) {
        final result = await ask([first, 200]);
        expect(result.status, 200, reason: '$first');
        expect(result.asked, 2, reason: '$first');
        expect(
          result.log,
          'Database request asked again '
          '(${first is int ? first : 'no answer'}): '
          '/rest/v1/rpc/mark_duplicates\n',
        );
      }
    });

    test('only once, and not for an answer of the database itself', () async {
      await expectLater(
        ask([const SocketException('a'), const SocketException('b'), 200]),
        throwsA(isA<SocketException>()),
      );
      expect((await ask([503, 503, 200])).status, 503);
      for (final status in [200, 400, 409, 500]) {
        final result = await ask([status, 200]);
        expect(result.status, status);
        expect(result.asked, 1);
        expect(result.log, isEmpty);
      }
    });
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
      expect(result.log, contains('Scored 0 listing(s) in '));
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

  group('command line', () {
    ArgParser parser() => ArgParser()
      ..addFlag('dry-run', negatable: false)
      ..addOption('max', defaultsTo: '10');
    final out = StringBuffer();
    final err = StringBuffer();
    setUp(() {
      out.clear();
      err.clear();
      exitCode = 0;
    });
    tearDown(() => exitCode = 0);

    ArgResults? read(List<String> args, {int positional = 0}) =>
        readCommandLine(
          parser(),
          args,
          usage: 'Usage: test',
          positional: positional,
          atLeast: {'max': 1},
          out: out,
          err: err,
        );

    test('reads flags, numbers and plain arguments', () {
      final options = read(['site', '--dry-run', '--max=3'], positional: 1)!;
      expect(options.flag('dry-run'), isTrue);
      expect(intOption(options, 'max'), 3);
      expect(options.rest, ['site']);
      expect(intOption(read([])!, 'max'), 10);
      expect(read(['--max', '2'])!.option('max'), '2');
      expect(exitCode, 0);
      expect(err.toString(), isEmpty);
    });

    test('a mistake prints the usage and exits 64', () {
      for (final args in [
        ['--ful'],
        ['--max=0'],
        ['--max=x'],
        ['--dry-run=yes'],
        ['extra'],
      ]) {
        err.clear();
        exitCode = 0;
        expect(read(args), isNull, reason: '$args');
        expect(exitCode, 64, reason: '$args');
        expect(err.toString(), contains('Usage: test'), reason: '$args');
      }
      expect(read(['a', 'b'], positional: 1), isNull);
      expect(err.toString(), contains('Expected 1 argument(s), got 2'));
    });

    test('--help prints the options and stops without an error', () {
      expect(read(['--help']), isNull);
      expect(exitCode, 0);
      expect(out.toString(), allOf(contains('Usage: test'), contains('--max')));
    });
  });

  group('sitesToRead', () {
    test('every site when none is named, as the scheduled run asks', () {
      expect(sitesToRead([]), [FetchSite.standvirtual, FetchSite.olx]);
    });

    test('only the sites named, in their order', () {
      expect(sitesToRead(['olx']), [FetchSite.olx]);
      expect(sitesToRead(['olx', 'standvirtual']), [
        FetchSite.olx,
        FetchSite.standvirtual,
      ]);
    });
  });
}
