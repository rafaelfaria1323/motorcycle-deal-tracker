import 'dart:io';

import 'package:args/args.dart';
import 'package:collector/collector.dart';

/// The weekly score check (N.61): the estimates and the Deal Score against
/// the ads that likely sold. The report goes to stdout and to the run's
/// summary (`GITHUB_STEP_SUMMARY`). It changes nothing in the database.
Future<void> main(List<String> args) async {
  final options = readCommandLine(
    ArgParser()
      ..addOption(
        'days',
        defaultsTo: '28',
        help: 'Ads gone this recently (per model).',
      )
      ..addOption(
        'band-days',
        defaultsTo: '60',
        help: 'Ads first seen this recently (Deal Score bands).',
      )
      ..addOption(
        'horizon',
        defaultsTo: '14',
        help: 'A band\'s ad counts as sold when it left within these days.',
      ),
    args,
    atLeast: {'days': 1, 'band-days': 2, 'horizon': 1},
    usage: 'Usage: dart run bin/score_check.dart [options]',
  );
  if (options == null) return;
  final days = int.parse(options.option('days')!);
  final bandDays = int.parse(options.option('band-days')!);
  final horizon = int.parse(options.option('horizon')!);
  if (horizon >= bandDays) {
    stderr.writeln('--horizon must be shorter than --band-days.');
    exitCode = 64;
    return;
  }

  await withServiceClient((client) async {
    final store = ScoreCheckStore(client);
    final report = scoreCheckReport(
      models: await store.models(days),
      bands: await store.bands(bandDays, horizon),
      days: days,
      bandDays: bandDays,
      horizon: horizon,
    );
    stdout.write(report);
    final path = Platform.environment['GITHUB_STEP_SUMMARY'];
    if (path != null && path.isNotEmpty) {
      File(path).writeAsStringSync(report, mode: FileMode.append);
    }
  });
}
