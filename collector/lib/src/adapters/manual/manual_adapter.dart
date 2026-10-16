import 'dart:convert';
import 'dart:io';

import '../source_adapter.dart';
import 'manual_raw_listing.dart';

/// Reads listings from a JSON file filled in by hand.
class ManualAdapter implements SourceAdapter<ManualRawListing> {
  ManualAdapter(this.path);

  static const sourceId = 'manual';

  final String path;

  @override
  String get source => sourceId;

  @override
  Future<ParseResult<ManualRawListing>> read() async =>
      parse(await File(path).readAsString());

  /// Pure parsing step, separate from file access so it can be tested.
  /// Throws [FormatException] when the file is not a JSON array.
  ParseResult<ManualRawListing> parse(String text) {
    final decoded = jsonDecode(text);
    if (decoded is! List) {
      throw FormatException('Expected a JSON array of listings');
    }

    final records = <ManualRawListing>[];
    final issues = <ParseIssue>[];

    for (var i = 0; i < decoded.length; i++) {
      final item = decoded[i];
      if (item is! Map<String, dynamic>) {
        issues.add(ParseIssue(i, 'Expected a JSON object'));
        continue;
      }
      try {
        records.add(ManualRawListing.fromJson(item));
      } on FormatException catch (e) {
        issues.add(ParseIssue(i, e.message));
      }
    }

    return ParseResult(records, issues);
  }
}
