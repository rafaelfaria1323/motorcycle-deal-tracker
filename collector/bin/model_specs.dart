import 'dart:io';

import 'package:args/args.dart';
import 'package:collector/collector.dart';
import 'package:http/http.dart' as http;

/// The weekly specification step (N.76): the catalog models whose figures
/// are incomplete (or never checked) are looked up in API Ninjas (env
/// `API_NINJAS_KEY`); only empty figures are filled, and the figures the
/// API puts more than 10 % from the typed ones are reported, to stdout and
/// the run's summary (`GITHUB_STEP_SUMMARY`). Without a key it says so and
/// stops (exit 0). A refused key or an exhausted month fails the run. The
/// requests sent are stored as the day's usage (N.101).
Future<void> main(List<String> args) async {
  final options = readCommandLine(
    ArgParser()..addOption(
      'days',
      defaultsTo: '30',
      help: 'Ask again about an incomplete model after this many days.',
    ),
    args,
    atLeast: {'days': 1},
    usage: 'Usage: dart run bin/model_specs.dart [options]',
  );
  if (options == null) return;
  final apiKey = Platform.environment['API_NINJAS_KEY']?.trim() ?? '';
  if (apiKey.isEmpty) {
    stdout.writeln(
      'API_NINJAS_KEY is not set; the specification step is '
      'skipped.',
    );
    return;
  }

  await withServiceClient((client) async {
    final store = SpecsStore(client);
    final httpClient = http.Client();
    final api = ApiNinjasClient(apiKey: apiKey, httpClient: httpClient);
    try {
      final outcomes = await lookUpSpecs(
        await store.modelsToCheck(int.parse(options.option('days')!)),
        ask: api.motorcycles,
        store: store.store,
      );
      final report = specsReport(outcomes);
      stdout.write(report);
      final path = Platform.environment['GITHUB_STEP_SUMMARY'];
      if (path != null && path.isNotEmpty) {
        File(path).writeAsStringSync(report, mode: FileMode.append);
      }
      if (outcomes.any((o) => o.error != null)) exitCode = 1;
    } finally {
      httpClient.close();
      stdout.writeln('API Ninjas requests: ${api.requests}');
      await recordApiUsage(client, .apiNinjas, api.requests);
    }
  });
}
