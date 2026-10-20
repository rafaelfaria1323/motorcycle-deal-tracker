import 'dart:io';

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
