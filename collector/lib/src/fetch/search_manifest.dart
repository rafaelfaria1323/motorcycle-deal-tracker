import 'dart:convert';
import 'dart:io';

/// What a fetch run saved: the searches it was asked for and the search each
/// saved page belongs to. Written next to the pages, so an import knows which
/// searches it holds in full and removes only their missing listings.
class const SearchManifest({
  /// Every search address the run was asked to fetch, in order.
  required final List<String> planned,

  /// Saved page file name -> its search address.
  required final Map<String, String> files,

  /// Search address -> how many pages the site said it spans (from its
  /// first page); missing for a search whose first page wasn't saved.
  final Map<String, int> pages = const {},

  /// Searches a light run read only up to the ads published or renewed
  /// before its window (newest first, R.2): their other pages were left
  /// on purpose, so that isn't a read issue, but they aren't read in full
  /// and remove nothing.
  final Set<String> newestOnly = const {},
}) {
  static const fileName = 'searches.json';

  /// The searches with at least one saved page.
  Set<String> get fetched => files.values.toSet();

  Map<String, Object> toJson() => {
    'planned': planned,
    'files': files,
    'pages': pages,
    'newest_only': newestOnly.toList(),
  };

  Future<void> writeTo(String directory) =>
      File('$directory/$fileName').writeAsString(jsonEncode(toJson()));

  /// Null when the folder has no manifest (pages saved by hand).
  static Future<SearchManifest?> readFrom(String directory) async {
    final file = File('$directory/$fileName');
    if (!await file.exists()) return null;
    final Object? json;
    try {
      json = jsonDecode(await file.readAsString());
    } on FormatException {
      throw FormatException('$fileName in $directory is not valid JSON');
    }
    if (json is! Map<String, dynamic> ||
        json['planned'] is! List ||
        json['files'] is! Map ||
        (json['pages'] != null && json['pages'] is! Map) ||
        (json['newest_only'] != null && json['newest_only'] is! List)) {
      throw FormatException('$fileName in $directory is not a search manifest');
    }
    return SearchManifest(
      planned: List<String>.from(json['planned'] as List),
      files: Map<String, String>.from(json['files'] as Map),
      // Manifests written before the page counts were kept have none.
      pages: Map<String, int>.from(json['pages'] as Map? ?? const {}),
      newestOnly: Set<String>.from(json['newest_only'] as List? ?? const []),
    );
  }
}
