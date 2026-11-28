import 'dart:io';

import 'package:test/test.dart';

/// postgrest's `order()` sorts DESCENDING unless told otherwise, unlike
/// SQL: every call must say `ascending:` so none reverses a list by
/// accident (the catalog came newest model first, N.128).
void main() {
  test('every order() says which way it sorts', () {
    final unsaid = [
      for (final dir in ['lib', 'bin'])
        for (final file in Directory(dir).listSync(recursive: true))
          if (file is File && file.path.endsWith('.dart'))
            for (final call in orderCalls(file.readAsStringSync()))
              if (!call.contains('ascending:')) '${file.path}: $call',
    ];
    expect(unsaid, isEmpty);
  });

  test('a call is read to its closing parenthesis', () {
    expect(orderCalls("q.order('a').order(\n  'b',\n  ascending: true,\n)"), [
      "order('a')",
      "order(\n  'b',\n  ascending: true,\n)",
    ]);
  });
}

/// The `.order(...)` calls in [source], each up to its own closing
/// parenthesis.
List<String> orderCalls(String source) => [
  for (final match in RegExp(r'\.order\(').allMatches(source))
    source.substring(match.start + 1, _closing(source, match.end)),
];

int _closing(String source, int from) {
  var depth = 1;
  for (var i = from; i < source.length; i++) {
    if (source[i] == '(') depth++;
    if (source[i] == ')' && --depth == 0) return i + 1;
  }
  return source.length;
}
