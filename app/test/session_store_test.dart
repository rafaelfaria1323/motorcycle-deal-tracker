import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/platform/session_store.dart';

class _Store implements KeyValueStore {
  _Store([Map<String, String>? values]) : values = {...?values};

  final Map<String, String> values;
  var failWrites = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('no keystore');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  const key = 'sb-abc-auth-token';

  test(
    'reads the encrypted session and leaves the plain store alone',
    () async {
      final secure = _Store({key: 'new'});
      final plain = _Store({key: 'old'});
      expect(await loadSession(secure: secure, plain: plain, key: key), 'new');
      expect(plain.values, {key: 'old'});
    },
  );

  test('moves a session saved by an earlier build', () async {
    final secure = _Store();
    final plain = _Store({key: 'old', 'other': 'x'});
    expect(await loadSession(secure: secure, plain: plain, key: key), 'old');
    expect(secure.values, {key: 'old'});
    expect(plain.values, {'other': 'x'});
  });

  test('no session anywhere', () async {
    expect(
      await loadSession(secure: _Store(), plain: _Store(), key: key),
      isNull,
    );
  });

  test('keeps the plain copy when the encrypted store fails', () async {
    final secure = _Store()..failWrites = true;
    final plain = _Store({key: 'old'});
    expect(await loadSession(secure: secure, plain: plain, key: key), 'old');
    expect(plain.values, {key: 'old'});
  });
}
