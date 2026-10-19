import 'dart:convert';
import 'dart:io';

/// What a fetch run saved: the searches it was asked for and the search each
/// saved page belongs to. Written next to the pages, so an import knows which
/// searches it holds in full and removes only their missing listings.
class SearchManifest {
  const SearchManifest({required this.planned, required this.files});

  static const fileName = 'searches.json';

  /// Every search address the run was asked to fetch, in order.
  final List<String> planned;

  /// Saved page file name -> its search address.
  final Map<String, String> files;

  /// The searches with at least one saved page.
  Set<String> get fetched => files.values.toSet();

  Map<String, Object> toJson() => {'planned': planned, 'files': files};

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
        json['files'] is! Map) {
      throw FormatException('$fileName in $directory is not a search manifest');
    }
    return SearchManifest(
      planned: List<String>.from(json['planned'] as List),
      files: Map<String, String>.from(json['files'] as Map),
    );
  }
}
