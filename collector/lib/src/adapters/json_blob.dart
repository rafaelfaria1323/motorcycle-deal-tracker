import 'dart:convert';

import 'package:html/parser.dart';

/// Decodes Standvirtual's JSON script, regardless of attribute order or quotes.
Object? extractNextData(String html, {String hint = ''}) {
  final script = parse(html).querySelector('script#__NEXT_DATA__');
  if (script == null) throw FormatException('no __NEXT_DATA__ block$hint');
  return _decodeJsonBlob(script.text, '__NEXT_DATA__');
}

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

  return _decodeJsonBlob(match.group(1)!, name, quoted: quoted);
}

Object? _decodeJsonBlob(String text, String name, {bool quoted = false}) {
  try {
    final decoded = jsonDecode(text);
    if (!quoted) return decoded;
    if (decoded is! String) throw const FormatException();
    return jsonDecode(decoded);
  } on FormatException {
    throw FormatException('$name is not valid JSON');
  }
}
