import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/valuation/presentation/shortcut_script.dart';

void main() {
  final key = 'ab' * 32;

  test('the script carries the key and its version', () {
    final script = sharedAdScript(key);
    expect(script, contains("var KEY = '$key';"));
    expect(script, contains('version: $sharedAdScriptVersion,'));
    expect(script, contains('completion(JSON.stringify('));
    expect(script, isNot(contains('__')));
  });

  test("the shared shortcut's script carries no key", () {
    final script = sharedAdScript();
    expect(script, contains('var KEY = null;'));
    expect(script, contains('p_key: KEY,'));
    expect(script, isNot(contains('__')));
  });

  test('the shared header is the one the database reads', () {
    final schema = File('../supabase/schema.sql').readAsStringSync();
    expect(schema, contains("->> '$sharedAdKeyHeader'"));
  });

  test('only a key the database made goes in', () {
    expect(() => sharedAdScript("x'; alert(1); '"), throwsArgumentError);
    expect(() => sharedAdScript(key.toUpperCase()), throwsArgumentError);
  });

  test("the version is the database's", () {
    // supabase/schema.sql holds today's `shared_ad_script_version()`.
    final schema = File('../supabase/schema.sql').readAsStringSync();
    final version = RegExp(
      r'FUNCTION public\.shared_ad_script_version\(\)[\s\S]*?select (\d+)',
    ).firstMatch(schema);
    expect(version, isNotNull);
    expect(int.parse(version!.group(1)!), sharedAdScriptVersion);
  });
}
