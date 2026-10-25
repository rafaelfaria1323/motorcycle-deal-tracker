import 'package:collector/src/adapters/json_blob.dart';
import 'package:test/test.dart';

void main() {
  final state = RegExp(
    r'window\.__PRERENDERED_STATE__\s*=\s*("(?:[^"\\]|\\.)*")',
  );

  for (final opening in [
    '<script id="__NEXT_DATA__" type="application/json">',
    "<script type='application/json' id='__NEXT_DATA__'>",
    '<SCRIPT nonce=">" id = __NEXT_DATA__ type="application/json">',
  ]) {
    test('reads JSON from $opening', () {
      expect(extractNextData('$opening{"a":[1,2]}</script>'), {
        'a': [1, 2],
      });
    });
  }

  test('only reads a script, not an id in a comment or another element', () {
    const html = '''
<!-- <script id="__NEXT_DATA__">{"wrong":true}</script> -->
<div id="__NEXT_DATA__">{"wrong":true}</div>
<script id="other">{"wrong":true}</script>
<script id="__NEXT_DATA__">{"right":true,"text":"&quot;","raw":"&#99999999999999999999;"}</script>
''';
    expect(extractNextData(html), {
      'right': true,
      'text': '&quot;',
      'raw': '&#99999999999999999999;',
    });
    expect(
      () => extractNextData('<div id="__NEXT_DATA__">{}</div>'),
      throwsFormatException,
    );
  });

  test('reads JSON written inside a JSON string', () {
    const html = r'<script>window.__PRERENDERED_STATE__= "{\"a\":1}";</script>';
    expect(extractJsonBlob(html, state, 'S', quoted: true), {'a': 1});
  });

  test('a missing block is a FormatException naming it, with the hint', () {
    expect(
      () => extractNextData('<html></html>', hint: ' (?)'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'no __NEXT_DATA__ block (?)',
        ),
      ),
    );
  });

  test('a damaged block is a FormatException', () {
    const damaged = '<script id="__NEXT_DATA__">{"a":</script>';
    expect(
      () => extractNextData(damaged),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          '__NEXT_DATA__ is not valid JSON',
        ),
      ),
    );
  });

  test('a quoted block that is not a JSON string is a FormatException', () {
    const html = '<script>window.__PRERENDERED_STATE__= "not json";</script>';
    expect(
      () => extractJsonBlob(html, state, 'S', quoted: true),
      throwsFormatException,
    );
  });

  test('missing or invalid OLX state keeps its named error', () {
    expect(
      () => extractJsonBlob('', state, 'S', hint: ' (?)'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'no S block (?)',
        ),
      ),
    );
    expect(
      () => extractJsonBlob(
        'window.__PRERENDERED_STATE__ = "bad\\q"',
        state,
        'S',
        quoted: true,
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'S is not valid JSON',
        ),
      ),
    );
    expect(
      () => extractJsonBlob(
        'window.__PRERENDERED_STATE__ = 7',
        RegExp(r'=\s*(\d+)'),
        'S',
        quoted: true,
      ),
      throwsFormatException,
    );
  });
}
