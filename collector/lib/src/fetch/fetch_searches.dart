import 'dart:io';

import '../adapters/olx/olx_search_adapter.dart';
import '../adapters/standvirtual/standvirtual_search_adapter.dart';
import 'polite_fetcher.dart';
import 'search_manifest.dart';

/// How a fetch of searches ended.
class FetchOutcome {
  const FetchOutcome({required this.saved, this.stoppedBy, this.failure});

  /// Pages saved.
  final int saved;

  /// Why it stopped early (the request budget ran out, a request failed or
  /// the site pushed back); null when every search was read.
  final String? stoppedBy;

  /// The failure or block that stopped it after some pages were saved
  /// ([FetchFailed] or [FetchBlocked]): the pages are imported all the
  /// same, and then the caller throws it, so the run still counts as
  /// failed.
  final Exception? failure;
}

/// Saves every page of [searches] into [directory] with [fetcher], which
/// must be prepared, and writes the [SearchManifest]. A search spanning
/// pages (OLX: 40 listings each, Standvirtual: 32) has the following pages
/// fetched too.
///
/// Running out of requests after some pages were saved is not an error:
/// the outcome says so and the import uses what was saved. A failed
/// request (a timeout) or a block after some pages were saved ends the
/// same way, with the failure in [FetchOutcome.failure]. Anything before a
/// page was saved throws, after the manifest of what was saved is written.
/// A search with a page missing is not read in full, so the import never
/// removes its listings.
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
  } on FetchFailed catch (e) {
    if (saved.isEmpty) rethrow;
    return _stoppedBy(e, started, searches.length, saved.length, log);
  } on FetchBlocked catch (e) {
    if (saved.isEmpty) rethrow;
    return _stoppedBy(e, started, searches.length, saved.length, log);
  } finally {
    if (saved.isNotEmpty) {
      await SearchManifest(
        planned: [for (final url in searches) '$url'],
        files: saved,
      ).writeTo(directory);
    }
  }
}

FetchOutcome _stoppedBy(
  Exception e,
  int started,
  int searches,
  int saved,
  StringSink log,
) {
  final cut = searches - started + 1;
  log.writeln(
    'Stopped: $e. $cut of $searches search(es) not read in full this run; '
    'the $saved page(s) saved are imported.',
  );
  return FetchOutcome(saved: saved, stoppedBy: '$e', failure: e);
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
