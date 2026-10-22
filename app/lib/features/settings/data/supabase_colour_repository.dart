import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/colour_repository.dart';

class SupabaseColourRepository implements ColourRepository {
  SupabaseColourRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<String>> getColours() async {
    // Row-level security returns only the current user's row.
    final row = await _client
        .from('user_colours')
        .select('colours')
        .maybeSingle();
    return List<String>.from(row?['colours'] as List? ?? const []);
  }

  @override
  Future<void> saveColours(List<String> codes) async {
    // The user id defaults to the signed-in user.
    await _client.from('user_colours').upsert({
      'colours': codes,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }
}
