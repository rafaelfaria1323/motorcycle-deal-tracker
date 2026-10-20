import 'dart:io';

import 'package:collector/collector.dart';

/// Writes the search addresses of the tracked models for one site, one per
/// line, for `fetch.dart`. An empty file means no tracked model has a search
/// on that site.
Future<void> main(List<String> args) async {
  final site = args.isEmpty ? null : FetchSite.byName[args.first];
  final out = args
      .skip(1)
      .where((a) => a.startsWith('--out='))
      .map((a) => a.substring('--out='.length))
      .firstOrNull;
  if (site == null || out == null || args.length != 2) {
    stderr.writeln(
      'Usage: dart run bin/searches.dart '
      '<${FetchSite.byName.keys.join('|')}> --out=<file>',
    );
    exitCode = 64;
    return;
  }

  await withServiceClient((client) async {
    final plan = planSearches(await loadCatalog(client), site);

    for (final problem in plan.problems) {
      stderr.writeln('Skipped: $problem');
    }
    await File(out).writeAsString(
      [
        for (final s in plan.searches) '${s.url}  # ${s.models.join(', ')}\n',
      ].join(),
    );

    stdout.writeln('${plan.searches.length} ${args.first} search(es):');
    for (final s in plan.searches) {
      stdout.writeln('  ${s.models.join(', ')}');
    }
  });
}
