import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/listing_card_preferences.dart';
import '../../domain/repositories/listing_card_preferences_repository.dart';

class SupabaseListingCardPreferencesRepository
    implements ListingCardPreferencesRepository {
  SupabaseListingCardPreferencesRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'listing_card_preferences';

  @override
  Future<ListingCardPreferences> get(String userId) async {
    final row = await _client
        .from(_table)
        .select('visible_fields')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return const ListingCardPreferences.defaults();
    final codes = List<String>.from(row['visible_fields'] as List);
    return ListingCardPreferences(
      codes.map(
        (code) => ListingCardField.values.firstWhere(
          (field) => field.code == code,
          orElse: () => throw FormatException('Unknown card field: $code'),
        ),
      ),
    );
  }

  @override
  Future<void> save(String userId, ListingCardPreferences preferences) async {
    // Keep the initiating account explicit if the session changes in flight.
    await _client.from(_table).upsert({
      'user_id': userId,
      'visible_fields': [
        for (final field in ListingCardField.values)
          if (preferences.shows(field)) field.code,
      ],
    }, onConflict: 'user_id');
  }
}
