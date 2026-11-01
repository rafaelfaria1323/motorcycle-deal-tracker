import 'dart:io';

import 'package:args/args.dart';
import 'package:collector/collector.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('dry-run', negatable: false, help: 'Nothing is stored.')
    ..addFlag(
      'full',
      negatable: false,
      help:
          'The input lists EVERY live listing of this source; listings '
          'missing from it are marked removed.',
    )
    ..addFlag(
      'force',
      negatable: false,
      help: 'Skip the safety limit on removals.',
    );
  final options = readCommandLine(
    parser,
    args,
    positional: 2,
    usage:
        'Usage: dart run bin/collector.dart <${sourceKinds.join('|')}> <path> '
        '[options]\n'
        '  manual        <path> is a JSON file\n'
        '  standvirtual  <path> is a folder of page results\n'
        '  standvirtual-search  <path> is a folder of search results pages\n'
        '  olx-search    <path> is a folder of search results pages',
  );
  if (options == null) return;
  final [kind, path] = options.rest;
  if (!sourceKinds.contains(kind)) {
    stderr.writeln('Unknown source "$kind": one of ${sourceKinds.join(', ')}.');
    exitCode = 64;
    return;
  }
  final dryRun = options.flag('dry-run');
  final full = options.flag('full');
  final force = options.flag('force');

  await withServiceClient((client) async {
    final catalog = await loadCatalog(client);
    final batch = await loadBatch(kind, path, catalog);

    final store = dryRun ? null : ListingStore(client);
    final cleanInput = await importBatch(
      batch,
      catalog,
      store: store,
      full: full,
      force: force,
    );
    if (!cleanInput) exitCode = 65;
    if (store != null) await finishRun(store, PushStore(client));
  });
}
