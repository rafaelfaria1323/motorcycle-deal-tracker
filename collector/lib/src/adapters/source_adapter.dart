import '../fetch/search_manifest.dart';
import 'site_model.dart';

/// One record that could not be read; the rest of the file is still used.
class ParseIssue {
  const ParseIssue(this.index, this.message, {this.search});

  /// Zero-based position of the record in the source.
  final int index;
  final String message;

  /// The search the problem belongs to, when the input says (see
  /// [SearchManifest]); that search then counts as not read in full.
  final String? search;

  @override
  String toString() => '#$index: $message';
}

class ParseResult<T> {
  const ParseResult(
    this.records,
    this.issues, {
    this.recordSearches,
    this.manifest,
    this.siteModels = const [],
  });

  final List<T> records;
  final List<ParseIssue> issues;

  /// The search each record was found by, in the order of [records]; null
  /// when the input has no manifest.
  final List<String?>? recordSearches;

  /// What the fetch run planned and saved; null for pages saved by hand.
  final SearchManifest? manifest;

  /// The brands and models the site offers, from its search filters.
  final List<SiteModel> siteModels;
}

/// A source-specific reader. It returns raw records in the source's own shape;
/// turning them into the normalized listing model happens elsewhere.
abstract interface class SourceAdapter<T> {
  /// Stable id stored in `listings.source`.
  String get source;

  Future<ParseResult<T>> read();
}
