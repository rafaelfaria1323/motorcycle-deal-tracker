import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/listing_filters.dart';
import '../../domain/entities/saved_search.dart';
import '../../domain/repositories/saved_searches_repository.dart';
import '../models/saved_search_model.dart';

class SupabaseSavedSearchesRepository implements SavedSearchesRepository {
  SupabaseSavedSearchesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<SavedSearch> create({
    required String name,
    required ListingFilters filters,
  }) async {
    final row = await _client
        .from('saved_searches')
        .insert(SavedSearchModel.toInsert(name, filters))
        .select()
        .single();
    return SavedSearchModel.fromJson(row);
  }

  @override
  Future<List<SavedSearch>> getAll() async {
    // Row-level security returns only the current user's searches.
    final rows = await _client
        .from('saved_searches')
        .select()
        .order('created_at', ascending: false);
    return rows.map<SavedSearch>(SavedSearchModel.fromJson).toList();
  }

  @override
  Future<SavedSearch> update(SavedSearch search) async {
    // `.single()` fails when no row was updated (for example, someone else's
    // search), so a blocked edit surfaces as an error instead of silently
    // doing nothing.
    final row = await _client
        .from('saved_searches')
        .update(SavedSearchModel.toUpdate(search))
        .eq('id', search.id)
        .select()
        .single();
    return SavedSearchModel.fromJson(row);
  }
}
