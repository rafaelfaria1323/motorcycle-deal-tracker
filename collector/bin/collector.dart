import 'dart:io';

import 'package:collector/collector.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2 || args.first != 'manual') {
    stderr.writeln('Usage: dart run bin/collector.dart manual <file.json>');
    exitCode = 64;
    return;
  }

  final adapter = ManualAdapter(args[1]);
  try {
    final result = await adapter.read();
    stdout.writeln('Source: ${adapter.source}');
    stdout.writeln(
      'Parsed ${result.records.length} listing(s), '
      '${result.issues.length} issue(s).',
    );
    for (final r in result.records) {
      stdout.writeln('  - ${r.brand} ${r.model} ${r.year ?? '-'} · ${r.priceEur} EUR');
    }
    for (final issue in result.issues) {
      stdout.writeln('  ! $issue');
    }
  } on FileSystemException catch (e) {
    stderr.writeln('Cannot read file: ${e.message} (${e.path})');
    exitCode = 66;
  } on FormatException catch (e) {
    stderr.writeln('Invalid file: ${e.message}');
    exitCode = 65;
  }
}
