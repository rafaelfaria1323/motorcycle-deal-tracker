import 'dart:io';

import 'package:collector/collector.dart';
import 'package:supabase/supabase.dart';

const _knownFlags = {'--dry-run', '--full', '--force'};

Future<void> main(List<String> args) async {
  final flags = args.where((a) => a.startsWith('--')).toSet();
  final positional = args.where((a) => !a.startsWith('--')).toList();

  if (positional.length != 2 ||
      !sourceKinds.contains(positional.first) ||
      flags.difference(_knownFlags).isNotEmpty) {
    stderr.writeln(
      'Usage: dart run bin/collector.dart <${sourceKinds.join('|')}> <path> '
      '[--dry-run] [--full] [--force]\n'
      '  manual        <path> is a JSON file\n'
      '  standvirtual  <path> is a folder of page results\n'
      '  standvirtual-search  <path> is a folder of search results pages\n'
      '  --full   the input lists EVERY live listing of this source; '
      'listings missing from it are marked removed\n'
      '  --force  skip the safety limit on removals',
    );
    exitCode = 64;
    return;
  }
  final dryRun = flags.contains('--dry-run');
  final full = flags.contains('--full');
  final force = flags.contains('--force');

  SupabaseClient? client;
  try {
    final config = SupabaseConfig.fromEnvironment();
    client = SupabaseClient(config.url, config.serviceKey);

    final catalog = await loadCatalog(client);
    final batch = await loadBatch(positional.first, positional[1], catalog);

    await importBatch(
      batch,
      catalog,
      store: dryRun ? null : ListingStore(client),
      full: full,
      force: force,
    );
    if (!dryRun) await finishRun(ListingStore(client));
  } on ConfigException catch (e) {
    stderr.writeln('Configuration error: $e');
    exitCode = 78;
  } on FileSystemException catch (e) {
    stderr.writeln('Cannot read input: ${e.message} (${e.path})');
    exitCode = 66;
  } on FormatException catch (e) {
    stderr.writeln('Invalid input: ${e.message}');
    exitCode = 65;
  } on PostgrestException catch (e) {
    stderr.writeln('Database error: ${e.message}');
    exitCode = 70;
  } finally {
    await client?.dispose();
  }
}
