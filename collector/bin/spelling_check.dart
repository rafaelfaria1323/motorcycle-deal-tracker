import 'dart:io';

import 'package:args/args.dart';
import 'package:collector/collector.dart';

/// The weekly spelling check (N.137): words in recent ads one or two
/// letters off a word the description rules depend on, which the rules
/// read differently once corrected. No AI. The report goes to stdout and
/// to the run's summary (`GITHUB_STEP_SUMMARY`). It changes nothing in the
/// database.
Future<void> main(List<String> args) async {
  final options = readCommandLine(
    ArgParser()
      ..addOption('days', defaultsTo: '30', help: 'Ads seen this recently.')
      ..addOption(
        'top',
        defaultsTo: '30',
        help: 'Words in the report, most ads first.',
      ),
    args,
    atLeast: {'days': 1, 'top': 1},
    usage: 'Usage: dart run bin/spelling_check.dart [options]',
  );
  if (options == null) return;
  final days = int.parse(options.option('days')!);
  final top = int.parse(options.option('top')!);

  await withServiceClient((client) async {
    final store = SpellingCheckStore(client);
    final ads = await store.ads(days);
    final found = await findMisspellings(ads, store.ruleCodes);
    final report = spellingCheckReport(
      found: found,
      ads: ads.length,
      days: days,
      top: top,
    );
    stdout.write(report);
    final path = Platform.environment['GITHUB_STEP_SUMMARY'];
    if (path != null && path.isNotEmpty) {
      File(path).writeAsStringSync(report, mode: FileMode.append);
    }
  });
}
