import 'dart:io';

import 'package:collector/collector.dart';

Future<void> main(List<String> args) async {
  final flags = args.where((a) => a.startsWith('--')).toList();
  final positional = args.where((a) => !a.startsWith('--')).toList();

  var dryRun = false;
  String? outDir;
  int? maxRequests; // no cap
  for (final flag in flags) {
    if (flag == '--dry-run') {
      dryRun = true;
    } else if (flag.startsWith('--out=')) {
      outDir = flag.substring('--out='.length);
    } else if (flag.startsWith('--max=')) {
      maxRequests = int.tryParse(flag.substring('--max='.length)) ?? 0;
      if (maxRequests < 1) positional.add('?');
    } else {
      positional.add('?'); // forces the usage message
    }
  }

  final site = positional.isEmpty ? null : FetchSite.byName[positional.first];
  if (positional.length != 2 || site == null) {
    stderr.writeln(
      'Usage: dart run bin/fetch.dart <${FetchSite.byName.keys.join('|')}> '
      '<urls-file> [--dry-run] [--out=<dir>] [--max=<n>]\n'
      '  <urls-file>  one search address per line (# starts a comment)\n'
      '  --dry-run    check the addresses; nothing is requested\n'
      '  --max        at most <n> requests, robots.txt included (default: no '
      'cap)\n'
      '  OLX searches span pages; the following pages are fetched too.',
    );
    exitCode = 64;
    return;
  }
  final out = outDir ?? 'samples/${positional.first}/search';

  final urls = <Uri>[];
  try {
    for (final raw in await File(positional[1]).readAsLines()) {
      final line = raw.split('#').first.trim();
      if (line.isEmpty) continue;
      final url = Uri.tryParse(line);
      final problem = url == null
          ? 'not an address'
          : urlProblem(url, site: site);
      if (problem != null) {
        stderr.writeln('Refused "$line": $problem');
        exitCode = 64;
        return;
      }
      urls.add(url!);
    }
  } on FileSystemException catch (e) {
    stderr.writeln('Cannot read ${e.path}: ${e.message}');
    exitCode = 66;
    return;
  }

  if (urls.isEmpty) {
    stderr.writeln('No addresses in ${positional[1]}.');
    exitCode = 64;
    return;
  }
  stdout.writeln(
    '${urls.length} address(es)'
    '${maxRequests == null ? '' : ', limit $maxRequests request(s)'}.',
  );

  if (dryRun) {
    for (final url in urls) {
      stdout.writeln('  would fetch $url');
    }
    stdout.writeln('Dry run: nothing was requested.');
    return;
  }

  final fetcher = PoliteFetcher(
    site: site,
    policy: FetchPolicy(maxRequestsPerRun: maxRequests),
  );
  try {
    await fetcher.prepare();
    final outcome = await fetchSearches(fetcher, urls, out);
    if (outcome.failure case final failure?) throw failure;
    stdout.writeln('Done.');
  } on FetchRefused catch (e) {
    stderr.writeln('Not fetched: $e');
    exitCode = 75;
  } on FetchBlocked catch (e) {
    stderr.writeln('Stopped, the site pushed back: $e');
    stderr.writeln('No new requests for 24 hours.');
    exitCode = 75;
  } on FetchFailed catch (e) {
    stderr.writeln('Failed: $e');
    exitCode = 75;
  } on FormatException catch (e) {
    stderr.writeln('Not a search results page: ${e.message}');
    exitCode = 65;
  } finally {
    fetcher.close();
  }
}
