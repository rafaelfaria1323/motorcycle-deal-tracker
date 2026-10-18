import 'package:collector/collector.dart';
import 'package:test/test.dart';

void main() {
  test('reads the url and key from the environment', () {
    final config = SupabaseConfig.fromEnvironment({
      'SUPABASE_URL': 'https://abc.supabase.co',
      'SUPABASE_SERVICE_ROLE_KEY': 'secret-key',
    });

    expect(config.url, 'https://abc.supabase.co');
    expect(config.serviceKey, 'secret-key');
  });

  test('fails clearly when something is missing', () {
    expect(
      () => SupabaseConfig.fromEnvironment({'SUPABASE_URL': 'https://x.co'}),
      throwsA(isA<ConfigException>()),
    );
  });

  test('rejects a url that is not http(s)', () {
    expect(
      () => SupabaseConfig.fromEnvironment({
        'SUPABASE_URL': 'abc.supabase.co',
        'SUPABASE_SERVICE_ROLE_KEY': 'secret-key',
      }),
      throwsA(isA<ConfigException>()),
    );
  });

  test('never prints the key', () {
    final config = SupabaseConfig.fromEnvironment({
      'SUPABASE_URL': 'https://abc.supabase.co',
      'SUPABASE_SERVICE_ROLE_KEY': 'secret-key',
    });

    expect(config.toString(), isNot(contains('secret-key')));
  });
}
