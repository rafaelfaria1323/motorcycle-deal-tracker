/// One record that could not be read; the rest of the file is still used.
class ParseIssue {
  const ParseIssue(this.index, this.message);

  /// Zero-based position of the record in the source.
  final int index;
  final String message;

  @override
  String toString() => '#$index: $message';
}

class ParseResult<T> {
  const ParseResult(this.records, this.issues);

  final List<T> records;
  final List<ParseIssue> issues;
}

/// A source-specific reader. It returns raw records in the source's own shape;
/// turning them into the normalized listing model happens elsewhere.
abstract interface class SourceAdapter<T> {
  /// Stable id stored in `listings.source`.
  String get source;

  Future<ParseResult<T>> read();
}