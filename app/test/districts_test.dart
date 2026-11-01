import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/districts.dart';

void main() {
  test("the filter's districts are the database's, in its order", () {
    // supabase/schema.sql holds today's `district_names()`.
    final schema = File('../supabase/schema.sql').readAsStringSync();
    final body = RegExp(
      r'FUNCTION public\.district_names\(\)[\s\S]*?ARRAY\[([^\]]*)\]',
      caseSensitive: false,
    ).firstMatch(schema);
    expect(body, isNotNull);
    final names = RegExp("'([^']*)'")
        .allMatches(body!.group(1)!)
        .map((m) => m.group(1))
        .toList();
    expect(portugueseDistricts, names);
  });
}
