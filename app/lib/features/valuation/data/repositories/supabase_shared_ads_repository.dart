import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/shared_ad.dart';
import '../../domain/repositories/shared_ads_repository.dart';

class SupabaseSharedAdsRepository implements SharedAdsRepository {
  SupabaseSharedAdsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<DateTime?> keyCreatedAt() async {
    final created = await _client.rpc<String?>('ad_import_key_created_at');
    return created == null ? null : DateTime.tryParse(created);
  }

  @override
  Future<String> createKey() => _client.rpc<String>('create_ad_import_key');

  @override
  Future<void> removeKey() => _client.rpc<void>('remove_ad_import_key');

  @override
  Future<List<SharedAd>> waiting() async {
    final rows = await _client.rpc<List<dynamic>>('my_shared_ads');
    return [for (final row in rows) ?sharedAdOf(row as Map<String, dynamic>)];
  }

  @override
  Future<void> dismiss(String id) =>
      _client.rpc<void>('dismiss_shared_ad', params: {'p_id': id});
}

/// A `my_shared_ads` row; null when it can't be read.
SharedAd? sharedAdOf(Map<String, dynamic> row) {
  final id = row['id'] as String?;
  final url = row['url'] as String?;
  final received = DateTime.tryParse(row['received_at'] as String? ?? '');
  if (id == null || url == null || received == null) return null;
  List<String> texts(Object? value) => [
    if (value is List)
      for (final item in value)
        if (item is String) item,
  ];
  return SharedAd(
    id: id,
    receivedAt: received,
    url: url,
    title: row['title'] as String?,
    description: row['description'] as String?,
    price: row['price'] as String?,
    lines: texts(row['lines']),
    photos: texts(row['photos']),
    scriptVersion: (row['script_version'] as num?)?.toInt() ?? 0,
  );
}
