import 'dart:io';

import '../adapters/olx/olx_search_adapter.dart';
import '../adapters/standvirtual/standvirtual_search_adapter.dart';
import 'polite_fetcher.dart';
import 'search_manifest.dart';

/// How a fetch of searches ended.
class FetchOutcome {
  const FetchOutcome({required this.saved, this.stoppedBy});

  /// Pages saved.
  final int saved;

  /// Why it stopped early (the request budget ran out); null when every
  /// search was read.
  final String? stoppedBy;
}

/// Saves every page of [searches] into [directory] with [fetcher], which
/// must be prepared, and writes the [SearchManifest]. A search spanning
/// pages (OLX: 40 listings each, Standvirtual: 32) has the following pages
/// fetched too.
///
/// Running out of requests after some pages were saved is not an error:
/// the outcome says so and the import uses what was saved. A block, a
/// failure, or running out before anything was saved throws, after the
/// manifest of what was saved is written.
Future<FetchOutcome> fetchSearches(
  PoliteFetcher fetcher,
  List<Uri> searches,
  String directory, {
  StringSink? out,
}) async {
  final log = out ?? stdout;
  await Directory(directory).create(recursive: true);

  // Which search each saved page belongs to, so the import removes only
  // listings of searches saved in full.
  final saved = <String, String>{};
  var started = 0;

  Future<String> save(Uri url, Uri search) async {
    final html = await fetcher.get(url);
    final name = fileNameFor(url);
    await File('$directory/$name').writeAsString(html);
    saved[name] = '$search';
    log.writeln('  saved $directory/$name (${html.length ~/ 1024} KB)');
    return html;
  }

  try {
    for (final url in searches) {
      started++;
      final first = await save(url, url);
      final olx = fetcher.site.host == FetchSite.olx.host;
      final pages = _totalPages(first, olx: olx);
      for (var page = 2; page <= pages; page++) {
        await save(
          olx
              ? OlxSearchAdapter.pageUrl(url, page)
              : StandvirtualSearchAdapter.pageUrl(url, page),
          url,
        );
      }
    }
    return FetchOutcome(saved: saved.length);
  } on FetchLimitReached catch (e) {
    if (saved.isEmpty) rethrow;
    // A search cut short keeps its listings as they are until a run reads
    // it in full.
    final cut = searches.length - started + 1;
    log.writeln(
      'Stopped: $e. $cut of ${searches.length} search(es) not read in full '
      'this run.',
    );
    return FetchOutcome(saved: saved.length, stoppedBy: '$e');
  } finally {
    if (saved.isNotEmpty) {
      await SearchManifest(
        planned: [for (final url in searches) '$url'],
        files: saved,
      ).writeTo(directory);
    }
  }
}

/// How many pages the search whose first page is [html] spans; 1 when the
/// page can't be read (the import reports it).
int _totalPages(String html, {required bool olx}) {
  try {
    return olx
        ? OlxSearchAdapter('').parseSearchPage(html).totalPages
        : StandvirtualSearchAdapter('').parseSearchPage(html).totalPages;
  } on FormatException {
    return 1;
  }
}
