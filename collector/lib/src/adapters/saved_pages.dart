import 'dart:convert';
import 'dart:io';

import '../fetch/search_manifest.dart';
import 'site_model.dart';
import 'source_adapter.dart';

/// The `.html` files of [directory], sorted by path.
/// Throws [FileSystemException] when the folder does not exist.
Future<List<File>> listHtmlFiles(String directory) async {
  final dir = Directory(directory);
  if (!await dir.exists()) {
    throw FileSystemException('Folder not found', directory);
  }
  return (await dir.list().toList())
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.html'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

/// An issue for file [index] (called [name]) when it was saved longer than
/// [maxAge] ago, otherwise null.
ParseIssue? staleIssue(
  int index,
  String name,
  Duration age,
  Duration maxAge, {
  String? search,
}) {
  if (age <= maxAge) return null;
  return ParseIssue(
    index,
    '$name: saved ${age.inHours} h ago (older than '
    '${maxAge.inHours} h), so it may be out of date',
    search: search,
  );
}

/// What the sites' search pages have in common, read by
/// [readSavedSearchPages].
class SearchPageParts<R> {
  const SearchPageParts({
    required this.records,
    required this.problems,
    required this.models,
  });

  final List<R> records;

  /// Results on the page that could not be read.
  final List<String> problems;
  final List<SiteModel> models;
}

/// Reads the saved search pages of [directory] with [parse] (which throws
/// [FormatException] for a page it cannot use): records, models, the pages'
/// own problems, stale files and unreadable ones, each tied to the search
/// that the manifest says found the file.
///
/// [onPage] sees every page read (for the site's bookkeeping) and [finish]
/// runs once after the last file, returning the site's own issues (such as
/// pages missing from a search).
Future<ParseResult<R>> readSavedSearchPages<R, P>(
  String directory,
  Duration maxAge, {
  required P Function(String html) parse,
  required SearchPageParts<R> Function(P page) parts,
  required void Function(P page, int index, String name, String? search) onPage,
  required Iterable<ParseIssue> Function() finish,
}) async {
  final files = await listHtmlFiles(directory);
  final manifest = await SearchManifest.readFrom(directory);
  final recordSearches = <String?>[];
  final records = <R>[];
  final issues = <ParseIssue>[];
  final models = <SiteModel>[];

  for (var i = 0; i < files.length; i++) {
    final name = files[i].uri.pathSegments.last;
    final search = manifest?.files[name];
    try {
      final bytes = await files[i].readAsBytes();
      final page = parse(utf8.decode(bytes, allowMalformed: true));
      final read = parts(page);
      records.addAll(read.records);
      recordSearches.addAll([for (final _ in read.records) search]);
      models.addAll(read.models);
      onPage(page, i, name, search);

      for (final problem in read.problems) {
        issues.add(ParseIssue(i, '$name: $problem', search: search));
      }
      final age = DateTime.now().difference(await files[i].lastModified());
      final stale = staleIssue(i, name, age, maxAge, search: search);
      if (stale != null) issues.add(stale);
    } on FormatException catch (e) {
      issues.add(ParseIssue(i, '$name: ${e.message}', search: search));
    }
  }
  issues.addAll(finish());
  return ParseResult(
    records,
    issues,
    recordSearches: manifest == null ? null : recordSearches,
    manifest: manifest,
    siteModels: uniqueSiteModels(models),
  );
}
