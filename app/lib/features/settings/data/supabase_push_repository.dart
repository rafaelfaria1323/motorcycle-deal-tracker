import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/platform/push.dart';
import '../domain/push_repository.dart';
import '../domain/quiet_hours.dart';

class SupabasePushRepository implements PushRepository {
  SupabasePushRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<String?> publicKey() async {
    final row = await _client
        .from('push_config')
        .select('public_key')
        .maybeSingle();
    return row?['public_key'] as String?;
  }

  @override
  Future<void> save(PushSubscription subscription) async {
    await _client.rpc<Object?>(
      'save_push_subscription',
      params: {
        'p_endpoint': subscription.endpoint,
        'p_p256dh': subscription.p256dh,
        'p_auth': subscription.auth,
      },
    );
  }

  @override
  Future<void> remove(String endpoint) async {
    // Row-level security deletes only the account's own device.
    await _client.from('push_subscriptions').delete().eq('endpoint', endpoint);
  }

  @override
  Future<QuietHours> quietHours() async {
    // Row-level security returns only the account's own row.
    final row = await _client
        .from('quiet_hours')
        .select('enabled, start_hour, end_hour')
        .maybeSingle();
    if (row == null) return QuietHours.standard;
    return QuietHours(
      enabled: row['enabled'] as bool,
      startHour: row['start_hour'] as int,
      endHour: row['end_hour'] as int,
    );
  }

  @override
  Future<void> saveQuietHours(QuietHours hours) async {
    // The user id defaults to the signed-in user.
    await _client.from('quiet_hours').upsert({
      'enabled': hours.enabled,
      'start_hour': hours.startHour,
      'end_hour': hours.endHour,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }
}
