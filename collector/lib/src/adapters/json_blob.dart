import 'dart:convert';

/// The `<script id="__NEXT_DATA__">` block of Standvirtual's pages.
final nextDataBlock = RegExp(
  r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>',
  dotAll: true,
);

/// Decodes the JSON that [pattern] captures (group 1) in [html].
///
/// With [quoted] the capture is a JSON string that itself holds JSON (OLX
/// writes its state that way). [name] is how the block is called in errors;
/// [hint] is added to the "no block" message.
/// Throws [FormatException] when the block is missing or is not valid JSON.
Object? extractJsonBlob(
  String html,
  RegExp pattern,
  String name, {
  bool quoted = false,
  String hint = '',
}) {
  final match = pattern.firstMatch(html);
  if (match == null) throw FormatException('no $name block$hint');

  try {
    final text = match.group(1)!;
    return jsonDecode(quoted ? jsonDecode(text) as String : text);
  } on Object {
    throw FormatException('$name is not valid JSON');
  }
}
