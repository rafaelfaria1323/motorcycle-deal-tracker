import 'dart:io';

import 'package:args/args.dart';
import 'package:collector/collector.dart';

Future<void> main(List<String> args) async {
  final options = readCommandLine(
    ArgParser()
      ..addFlag(
        'dry-run',
        negatable: false,
        help: 'Check the addresses; nothing is requested.',
      )
      ..addOption('out', help: 'Folder for the pages (samples/<site>/search).')
      ..addOption(
        'max',
        help: 'At most <n> requests, robots.txt included (default: no cap).',
      ),
    args,
    positional: 2,
    atLeast: {'max': 1},
    usage:
        'Usage: dart run bin/fetch.dart <${FetchSite.byName.keys.join('|')}> '
        '<urls-file> [options]\n'
        '  <urls-file>  one search address per line (# starts a comment)\n'
        '  Searches span pages; the following pages are fetched too.',
  );
  if (options == null) return;
  final [siteName, urlsFile] = options.rest;
  final site = FetchSite.byName[siteName];
  if (site == null) {
    stderr.writeln(
      'Unknown site "$siteName": one of ${FetchSite.byName.keys.join(', ')}.',
    );
    exitCode = 64;
    return;
  }
  final dryRun = options.flag('dry-run');
  final maxRequests = intOption(options, 'max'); // null: no cap
  final out = options.option('out') ?? 'samples/$siteName/search';

  final urls = <Uri>[];
  try {
    for (final raw in await File(urlsFile).readAsLines()) {
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
    stderr.writeln('No addresses in $urlsFile.');
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
