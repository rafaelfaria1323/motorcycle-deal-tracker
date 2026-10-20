import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/favourite.dart';
import '../../domain/repositories/favourites_repository.dart';
import '../models/favourite_model.dart';

class SupabaseFavouritesRepository implements FavouritesRepository {
  SupabaseFavouritesRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'listing_favourites';

  @override
  Future<List<Favourite>> getAll() async {
    // Row-level security returns only the current user's favourites.
    final rows = await _client
        .from(_table)
        .select(FavouriteModel.columns)
        .order('created_at', ascending: false);
    return rows.map<Favourite>(FavouriteModel.fromJson).toList();
  }

  @override
  Future<void> add(String listingId) async {
    // The user id defaults to the signed-in user.
    await _client.from(_table).insert({'listing_id': listingId});
  }

  @override
  Future<void> remove(String listingId) async {
    // Asking for the deleted rows back tells a blocked delete from a done one.
    final deleted = await _client
        .from(_table)
        .delete()
        .eq('listing_id', listingId)
        .select('listing_id');
    if (deleted.isEmpty) {
      throw StateError('Favourite $listingId was not removed.');
    }
  }

  @override
  Future<void> saveNote(String listingId, String? note) async {
    final updated = await _client
        .from(_table)
        .update({
          'note': note,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('listing_id', listingId)
        .select('listing_id');
    if (updated.isEmpty) {
      throw StateError('Favourite $listingId has no note to save.');
    }
  }

  @override
  Future<void> saveChecklist(
    String listingId,
    Map<String, ChecklistEntry> checklist,
  ) async {
    final updated = await _client
        .from(_table)
        .update({
          'checklist': FavouriteModel.checklistToJson(checklist),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('listing_id', listingId)
        .select('listing_id');
    if (updated.isEmpty) {
      throw StateError('Favourite $listingId has no checklist to save.');
    }
  }
}
