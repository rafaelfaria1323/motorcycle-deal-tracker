import 'dart:io';

import 'package:collector/collector.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2 || args.first != 'manual') {
    stderr.writeln('Usage: dart run bin/collector.dart manual <file.json>');
    exitCode = 64;
    return;
  }

  final adapter = ManualAdapter(args[1]);
  final mapper = ManualMapper(Catalog.mvp());

  try {
    final result = await adapter.read();
    stdout.writeln('Source: ${adapter.source}');
    stdout.writeln(
      'Read ${result.records.length} record(s), '
      '${result.issues.length} read issue(s).',
    );
    for (final issue in result.issues) {
      stdout.writeln('  ! $issue');
    }

    var mapped = 0;
    var rejected = 0;
    for (final raw in result.records) {
      switch (mapper.map(raw)) {
        case Mapped(:final listing, :final warnings):
          mapped++;
          stdout.writeln(
            '  - ${listing.motorcycleSlug ?? 'unmatched'} · '
            '${listing.year ?? '-'} · ${listing.price} EUR · '
            '${listing.sourceListingId}',
          );
          for (final warning in warnings) {
            stdout.writeln('      ~ $warning');
          }
        case Rejected(:final reason):
          rejected++;
          stdout.writeln('  ! ${raw.url}: $reason');
      }
    }
    stdout.writeln('Mapped $mapped, rejected $rejected.');
  } on FileSystemException catch (e) {
    stderr.writeln('Cannot read file: ${e.message} (${e.path})');
    exitCode = 66;
  } on FormatException catch (e) {
    stderr.writeln('Invalid file: ${e.message}');
    exitCode = 65;
  }
}
