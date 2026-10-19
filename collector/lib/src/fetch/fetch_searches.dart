import 'dart:io';

import '../adapters/olx/olx_search_adapter.dart';
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
/// must be prepared, and writes the [SearchManifest]. OLX searches span
/// pages; the following pages are fetched too.
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
      if (fetcher.site.host == FetchSite.olx.host) {
        final pages = OlxSearchAdapter('').parseSearchPage(first).totalPages;
        for (var page = 2; page <= pages; page++) {
          await save(OlxSearchAdapter.pageUrl(url, page), url);
        }
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
