import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/home_repository.dart';
import '../domain/place.dart';
import '../presentation/place_text.dart';

class SupabaseHomeRepository(final SupabaseClient _client)
    implements HomeRepository {
  @override
  Future<Place?> getHome() async {
    // Row-level security returns only the current user's home.
    final row = await _client
        .from('user_home')
        .select('places(key, name)')
        .maybeSingle();
    final place = row?['places'] as Map<String, dynamic>?;
    return place == null ? null : _place(place);
  }

  @override
  Future<List<Place>> search(String text) async {
    // Keys hold only letters, digits and spaces: drop LIKE's wildcards.
    final key = placeKey(text).replaceAll(RegExp(r'[%_\\]'), '');
    if (key.isEmpty) return const [];
    final rows = await _client
        .from('places')
        .select('key, name')
        .like('key', '$key%')
        .order('key')
        .limit(30);
    return uniquePlaces(rows.map(_place).toList()).take(10).toList();
  }

  @override
  Future<void> saveHome(Place place) async {
    // The user id defaults to the signed-in user.
    await _client.from('user_home').upsert({
      'place_key': place.key,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }

  Place _place(Map<String, dynamic> row) =>
      Place(key: row['key'] as String, name: row['name'] as String);
}
