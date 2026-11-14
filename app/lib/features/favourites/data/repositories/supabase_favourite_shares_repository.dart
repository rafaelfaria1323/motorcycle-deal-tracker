import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/favourite.dart';
import '../../domain/entities/favourite_share.dart';
import '../../domain/repositories/favourite_shares_repository.dart';
import '../models/favourite_model.dart';

/// The shares through the database's functions (the table itself has no
/// API access: `20261114220000_favourite_shares.sql`).
class SupabaseFavouriteSharesRepository(final SupabaseClient _client)
    implements FavouriteSharesRepository {
  @override
  Future<String> share() async =>
      await _client.rpc<Object?>('share_favourites') as String;

  @override
  Future<FavouriteShare> mine() async {
    final rows =
        await _client.rpc<Object?>('my_favourite_share') as List<dynamic>;
    if (rows.isEmpty) return FavouriteShare.none;
    final row = rows.first as Map<String, dynamic>;
    final expires = row['code_expires_at'] as String?;
    return FavouriteShare(
      viewerEmail: row['viewer_email'] as String?,
      code: expires == null ? null : row['code'] as String?,
      codeExpiresAt: expires == null ? null : DateTime.parse(expires),
    );
  }

  @override
  Future<void> stop() async {
    await _client.rpc<Object?>('stop_sharing_favourites');
  }

  @override
  Future<String> accept(String code) async =>
      await _client.rpc<Object?>(
            'accept_favourite_share',
            params: {'p_code': code},
          )
          as String;

  @override
  Future<List<SharedList>> sharedWithMe() async {
    final rows =
        await _client.rpc<Object?>('favourites_shared_with_me')
            as List<dynamic>;
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        SharedList(
          ownerId: row['owner_id'] as String,
          ownerEmail: row['owner_email'] as String? ?? '',
        ),
    ];
  }

  @override
  Future<void> leave(String ownerId) async {
    await _client.rpc<Object?>(
      'leave_shared_favourites',
      params: {'p_owner': ownerId},
    );
  }

  @override
  Future<List<Favourite>> favouritesOf(String ownerId) async {
    // The function returns rows of listing_favourites, so the listing is
    // embedded as for this account's own list.
    final rows = await _client
        .rpc<Object?>('shared_favourites', params: {'p_owner': ownerId})
        .select(FavouriteModel.columns);
    return rows.map<Favourite>(FavouriteModel.fromJson).toList();
  }
}
