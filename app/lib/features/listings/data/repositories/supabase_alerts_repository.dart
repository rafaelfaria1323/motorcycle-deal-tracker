import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/listing_alert.dart';
import '../../domain/repositories/alerts_repository.dart';
import '../models/listing_alert_model.dart';
import '../models/listing_model.dart';

class SupabaseAlertsRepository(final SupabaseClient _client)
    implements AlertsRepository {
  @override
  Future<List<ListingAlert>> getPage({
    required int limit,
    Set<AlertType> types = const {},
    int offset = 0,
  }) async {
    // Row-level security returns only the current user's alerts.
    var query = _client
        .from('alerts')
        .select(
          '*, listings(${ListingModel.summaryColumns}), saved_searches(name)',
        )
        .isFilter('dismissed_at', null);
    if (types.isNotEmpty) {
      query = query.inFilter('type', [
        for (final type in types) ?ListingAlertModel.code(type),
      ]);
    }
    // One run makes many alerts with the same time: the id keeps the pages
    // in one order.
    final rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .range(offset, offset + limit - 1);
    return rows.map<ListingAlert>(ListingAlertModel.fromJson).toList();
  }

  @override
  Future<int> countUnread() => _client
      .from('alerts')
      .count()
      .isFilter('read_at', null)
      .isFilter('dismissed_at', null);

  // Only `read_at` is directly writable; dismissal uses owner-checked RPCs.

  @override
  Future<void> markRead(String id) async {
    await _client
        .from('alerts')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  @override
  Future<void> markAllRead() async {
    await _client
        .from('alerts')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .isFilter('read_at', null);
  }

  @override
  Future<void> dismiss(String id) async {
    await _client.rpc<void>('dismiss_alert', params: {'p_alert': id});
  }

  @override
  Future<int> dismissRead() async {
    final count = await _client.rpc<Object?>('dismiss_read_alerts');
    return (count as num?)?.toInt() ?? 0;
  }
}
