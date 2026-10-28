import 'dart:io';

import 'package:clock/clock.dart';

import '../adapters/olx/olx_search_adapter.dart';
import '../adapters/standvirtual/standvirtual_search_adapter.dart';
import 'polite_fetcher.dart';
import 'search_plan.dart';
import 'search_manifest.dart';

/// A light run (R.2) reads a search newest first only when it was read in
/// full within this time: more than the longest gap between full runs
/// (00:00 to 08:00, collect.yml), so one failed full run doesn't make the
/// light runs after it read everything.
const lightRunWindow = Duration(hours: 12);

/// A light run reads back to this long before the search's last full read,
/// for ads the site's search shows some time after their date.
const lightRunMargin = Duration(hours: 2);

/// The date a light run reads [search] back to, or null when it must be
/// read in full: never read in full, or not within [lightRunWindow] of
/// [now] (also one "in the future", from a clock that moved).
DateTime? lightRunCutoff(DateTime? lastFullRead, DateTime now) {
  if (lastFullRead == null) return null;
  final age = now.toUtc().difference(lastFullRead);
  if (age.isNegative || age > lightRunWindow) return null;
  return lastFullRead.toUtc().subtract(lightRunMargin);
}

/// How a fetch of searches ended.
class FetchOutcome {
  const FetchOutcome({required this.saved, this.stoppedBy, this.failure});

  /// Pages saved.
  final int saved;

  /// Why it stopped early (the request budget ran out, a request failed or
  /// the site pushed back); null when every search was read.
  final String? stoppedBy;

  /// The failure, refusal or block that stopped it after some pages were
  /// saved ([FetchFailed], [FetchRefused] or [FetchBlocked]): the pages are imported all the
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
/// request (a timeout), a page our own rules refuse or a block after some
/// pages were saved ends the
/// same way, with the failure in [FetchOutcome.failure]. Anything before a
/// page was saved throws, after the manifest of what was saved is written.
/// A search with a page missing is not read in full, so the import never
/// removes its listings.
///
/// A search whose every page was saved is recorded in the fetch state
/// ([PoliteFetcher.markFullRead]). In a [light] run (R.2) a search read in
/// full lately ([lightRunCutoff]) is read newest first and stops after the
/// first page holding an ad, top ads aside, published or renewed before
/// that read: the pages after it hold only older ads, which it read. Such a
/// search is in [SearchManifest.newestOnly] (not a read issue, but not read
/// in full either); one whose every page was read anyway is read in full.
Future<FetchOutcome> fetchSearches(
  PoliteFetcher fetcher,
  List<Uri> searches,
  String directory, {
  bool light = false,
  StringSink? out,
}) async {
  final log = out ?? stdout;
  await Directory(directory).create(recursive: true);

  // Which search each saved page belongs to, so the import removes only
  // listings of searches saved in full.
  final saved = <String, String>{};
  // How many pages each search spans, for the run's record (R.1).
  final spans = <String, int>{};
  final newestOnly = <String>{};
  var started = 0;

  Future<String> save(Uri url, Uri search, {String? fetched}) async {
    final html = fetched ?? await fetcher.get(url);
    final name = fileNameFor(url);
    await File('$directory/$name').writeAsString(html);
    saved[name] = '$search';
    log.writeln('  saved $directory/$name (${html.length ~/ 1024} KB)');
    return html;
  }

  try {
    for (final url in searches) {
      started++;
      final olx = fetcher.site.host == FetchSite.olx.host;
      final newerThan = light
          ? lightRunCutoff(fetcher.fullReadAt(url), clock.now())
          : null;
      if (light && newerThan == null) {
        log.writeln(
          '  not read in full in the last ${lightRunWindow.inHours} h: '
          'read in full',
        );
      }
      // Standvirtual's own order is already newest first (by renewal).
      final first = newerThan != null && olx
          ? OlxSearchAdapter.newestFirst(url)
          : url;
      final html = await fetcher.get(first);
      if (olx && _emptyWithEngineBand(url, html)) {
        // Not saved, so the search is not read in full and removes nothing:
        // if the band's value were wrong, OLX would return no ads at all.
        log.writeln(
          '  OLX found no ads for $url with the engine-size filter; '
          'its listings are kept as they are (check olxEngineBands)',
        );
        continue;
      }
      await save(first, url, fetched: html);
      var (:pages, :oldest) = _pageFacts(html, olx: olx);
      spans['$url'] = pages;
      for (var page = 2; page <= pages; page++) {
        if (newerThan != null && oldest != null && oldest.isBefore(newerThan)) {
          newestOnly.add('$url');
          log.writeln(
            '  newest first: read ${page - 1} of $pages page(s), the rest '
            'is older than ${newerThan.toIso8601String()}',
          );
          break;
        }
        final next = await save(
          olx
              ? OlxSearchAdapter.pageUrl(first, page)
              : StandvirtualSearchAdapter.pageUrl(first, page),
          url,
        );
        oldest = _pageFacts(next, olx: olx).oldest;
      }
      if (!newestOnly.contains('$url')) await fetcher.markFullRead(url);
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
  } on FetchRefused catch (e) {
    // Our own rules refused a page (robots.txt, a redirect off the site's
    // listings): stopped like a failure, keeping what was saved.
    if (saved.isEmpty) rethrow;
    return _stoppedBy(e, started, searches.length, saved.length, log);
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
        pages: spans,
        newestOnly: newestOnly,
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

/// Whether [url] asks OLX for an engine-size band and its first page
/// [html] has no ads.
bool _emptyWithEngineBand(Uri url, String html) {
  if (!url.queryParameters.containsKey(olxEngineSize)) return false;
  try {
    return OlxSearchAdapter('').parseSearchPage(html).total == 0;
  } on FormatException {
    return false; // not a results page: saved, and the import reports it
  }
}

/// How many pages the search of page [html] spans, and the oldest
/// publication or renewal among its ads (top ads aside); 1 and null when
/// the page can't be read (the import reports it).
({int pages, DateTime? oldest}) _pageFacts(String html, {required bool olx}) {
  try {
    if (olx) {
      final page = OlxSearchAdapter('').parseSearchPage(html);
      return (pages: page.totalPages, oldest: page.oldestOrganic);
    }
    final page = StandvirtualSearchAdapter('').parseSearchPage(html);
    return (pages: page.totalPages, oldest: page.oldestOrganic);
  } on FormatException {
    return (pages: 1, oldest: null);
  }
}
