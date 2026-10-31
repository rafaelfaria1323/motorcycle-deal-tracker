import 'dart:io';

import 'package:args/args.dart';
import 'package:collector/collector.dart';

/// Writes the search addresses of the tracked models for one site, one per
/// line, for `fetch.dart`. An empty file means no tracked model has a search
/// on that site.
Future<void> main(List<String> args) async {
  final options = readCommandLine(
    ArgParser()..addOption('out', mandatory: true, help: 'The file to write.'),
    args,
    positional: 1,
    usage:
        'Usage: dart run bin/searches.dart '
        '<${FetchSite.byName.keys.join('|')}> --out=<file>',
  );
  if (options == null) return;
  final siteName = options.rest.single;
  final site = FetchSite.byName[siteName];
  if (site == null) {
    stderr.writeln(
      'Unknown site "$siteName": one of ${FetchSite.byName.keys.join(', ')}.',
    );
    exitCode = 64;
    return;
  }
  final out = options.option('out')!;

  await withServiceClient((client) async {
    final plan = planSearches(await loadCatalog(client), site);

    for (final problem in plan.problems) {
      stderr.writeln('Skipped: $problem');
    }
    await File(out).writeAsString(
      [for (final s in plan.searches) '${s.url}  # ${s.models.join(', ')}\n']
          .join(),
    );

    stdout.writeln('${plan.searches.length} $siteName search(es):');
    for (final s in plan.searches) {
      stdout.writeln('  ${s.models.join(', ')}');
    }
  });
}
