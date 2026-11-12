import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/favourite.dart';
import '../../domain/repositories/favourites_repository.dart';
import '../models/favourite_model.dart';

/// The favourites in the database, with a copy on this device (N.66): the
/// last list read, and the checklists the database has not taken yet,
/// each kept per account.
class SupabaseFavouritesRepository(
  final SupabaseClient _client,
  final SharedPreferences _device,
) implements FavouritesRepository {
  static const _table = 'listing_favourites';

  String? get _userId => _client.auth.currentUser?.id;

  static String _copyKey(String userId) => 'favourites_copy:$userId';

  static String _unsentKey(String userId) => 'unsent_checklists:$userId';

  @override
  Future<List<Favourite>> getAll() async {
    // Row-level security returns only the current user's favourites.
    final rows = await _client
        .from(_table)
        .select(FavouriteModel.columns)
        .order('created_at', ascending: false);
    final favourites = rows.map<Favourite>(FavouriteModel.fromJson).toList();
    final userId = _userId;
    if (userId != null) {
      // Only a convenience: a copy that can't be written is no error.
      try {
        await _device.setString(_copyKey(userId), jsonEncode(rows));
      } catch (_) {}
    }
    return favourites;
  }

  @override
  Future<List<Favourite>?> lastCopy() async {
    final userId = _userId;
    if (userId == null) return null;
    final text = _device.getString(_copyKey(userId));
    if (text == null) return null;
    try {
      return [
        for (final row in jsonDecode(text) as List)
          FavouriteModel.fromJson(row as Map<String, dynamic>),
      ];
    } catch (_) {
      // Damaged, or written by a build that read other columns.
      return null;
    }
  }

  @override
  Future<Map<String, Map<String, ChecklistEntry>>> unsentChecklists() async {
    final userId = _userId;
    if (userId == null) return const {};
    return FavouriteModel.unsentFromJson(_device.getString(_unsentKey(userId)));
  }

  @override
  Future<void> keepUnsentChecklist(
    String listingId,
    Map<String, ChecklistEntry>? checklist,
  ) async {
    final userId = _userId;
    if (userId == null) throw StateError('No account to keep it for.');
    final unsent = {...await unsentChecklists()};
    if (checklist == null) {
      if (unsent.remove(listingId) == null) return;
    } else {
      unsent[listingId] = checklist;
    }
    final saved = unsent.isEmpty
        ? await _device.remove(_unsentKey(userId))
        : await _device.setString(
            _unsentKey(userId),
            FavouriteModel.unsentToJson(unsent),
          );
    if (!saved) throw StateError('Could not keep the checklist here.');
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
  Future<void> saveTargetPrice(String listingId, double? targetPrice) async {
    // The database sets target_set_at, so only later prices alert.
    final updated = await _client
        .from(_table)
        .update({
          'target_price': targetPrice,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('listing_id', listingId)
        .select('listing_id');
    if (updated.isEmpty) {
      throw StateError('Favourite $listingId has no target price to save.');
    }
  }

  @override
  Future<void> saveVisit(String listingId, DateTime? visitAt) async {
    // The database forgets an earlier reminder when the time changes.
    final updated = await _client
        .from(_table)
        .update({
          'visit_at': visitAt?.toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('listing_id', listingId)
        .select('listing_id');
    if (updated.isEmpty) {
      throw StateError('Favourite $listingId has no visit to save.');
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
