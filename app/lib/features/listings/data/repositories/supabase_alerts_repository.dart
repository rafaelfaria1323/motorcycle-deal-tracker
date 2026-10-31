import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/listing_alert.dart';
import '../../domain/repositories/alerts_repository.dart';
import '../models/listing_alert_model.dart';
import '../models/listing_model.dart';

class SupabaseAlertsRepository(final SupabaseClient _client)
    implements AlertsRepository {
  @override
  Future<List<ListingAlert>> getAll() async {
    // Row-level security returns only the current user's alerts.
    final rows = await _client
        .from('alerts')
        .select(
          '*, listings(${ListingModel.summaryColumns}), saved_searches(name)',
        )
        .isFilter('dismissed_at', null)
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map<ListingAlert>(ListingAlertModel.fromJson).toList();
  }

  // Only `read_at` is directly writable; dismissal uses an owner-checked RPC.

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
}
