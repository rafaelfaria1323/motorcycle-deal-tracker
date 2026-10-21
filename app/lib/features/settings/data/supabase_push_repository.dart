import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/platform/push.dart';
import '../domain/push_repository.dart';

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
}
