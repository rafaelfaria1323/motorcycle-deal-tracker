import 'package:collector/src/adapters/json_values.dart';
import 'package:test/test.dart';

void main() {
  test('asMap keeps maps and drops anything else', () {
    expect(asMap({'a': 1}), {'a': 1});
    expect(asMap([1]), isNull);
    expect(asMap(null), isNull);
  });

  test('asList keeps lists and gives an empty one otherwise', () {
    expect(asList([1, 'a']), [1, 'a']);
    expect(asList({'a': 1}), isEmpty);
    expect(asList(null), isEmpty);
  });

  test('asInt takes any number, truncating decimals', () {
    expect(asInt(7), 7);
    expect(asInt(7.9), 7);
    expect(asInt('7'), isNull);
  });

  test('asTime reads ISO 8601 as UTC and ignores the rest', () {
    expect(
      asTime('2026-10-19T22:30:00+01:00'),
      DateTime.utc(2026, 10, 19, 21, 30),
    );
    expect(asTime('2026-10-19T21:30:00Z')!.isUtc, isTrue);
    expect(asTime('yesterday'), isNull);
    expect(asTime(1760000000), isNull);
  });
}
