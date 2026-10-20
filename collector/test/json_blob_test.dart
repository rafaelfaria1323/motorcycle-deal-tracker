import 'package:collector/src/adapters/json_blob.dart';
import 'package:test/test.dart';

void main() {
  final state = RegExp(
    r'window\.__PRERENDERED_STATE__\s*=\s*("(?:[^"\\]|\\.)*")',
  );

  test('reads the JSON of a script block', () {
    const html = '<script id="__NEXT_DATA__" type="x">{"a":[1,2]}</script>';
    expect(extractJsonBlob(html, nextDataBlock, 'X'), {
      'a': [1, 2],
    });
  });

  test('reads JSON written inside a JSON string', () {
    const html = r'<script>window.__PRERENDERED_STATE__= "{\"a\":1}";</script>';
    expect(extractJsonBlob(html, state, 'S', quoted: true), {'a': 1});
  });

  test('a missing block is a FormatException naming it, with the hint', () {
    expect(
      () => extractJsonBlob('<html></html>', nextDataBlock, 'X', hint: ' (?)'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'no X block (?)',
        ),
      ),
    );
  });

  test('a damaged block is a FormatException', () {
    const damaged = '<script id="__NEXT_DATA__">{"a":</script>';
    expect(
      () => extractJsonBlob(damaged, nextDataBlock, 'X'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'X is not valid JSON',
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
}
