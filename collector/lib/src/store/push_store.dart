import 'package:supabase/supabase.dart';

import '../../collector.dart';
import 'store_support.dart';

/// The accounts and what is pushed to them: alerts waiting, devices,
/// languages, admins, the answers to their requests, and the keys the
/// pushes and the database's account calls use.
class PushStore(final SupabaseClient _client) {
  /// Alerts of real accounts not pushed yet, oldest first. With [at],
  /// those of accounts in their quiet hours then are left out (they wait).
  Future<List<PendingAlert>> pendingNotifications({
    int limit = 20,
    DateTime? at,
  }) async {
    final rows = await _client.rpc<Object?>(
      'pending_notifications',
      params: {
        'p_limit': limit,
        if (at != null) 'p_at': at.toUtc().toIso8601String(),
      },
    ) as List<dynamic>;
    return [
      for (final row in rows) PendingAlert.fromRow(row as Map<String, dynamic>),
    ];
  }

  /// Complete preferences for these recipients. Only an absent row means
  /// Portuguese; a failed lookup must leave notifications pending.
  Future<Map<String, NotificationLanguage>> accountLanguages(
    List<String> userIds,
  ) async {
    final users = userIds.toSet().toList();
    final languages = {
      for (final user in users) user: NotificationLanguage.portuguese,
    };
    // Keep the filter below URL limits, even for a large summary batch.
    const batchSize = 100;
    for (var start = 0; start < users.length; start += batchSize) {
      final rows = await _client
          .from('account_languages')
          .select('user_id, language')
          .inFilter('user_id', users.skip(start).take(batchSize).toList());
      for (final row in rows) {
        languages[row['user_id'] as String] = NotificationLanguage.fromCode(
          row['language'] as String,
        );
      }
    }
    return languages;
  }

  /// Who asked for every photo of [ids] examined, for those now done
  /// (`photo_exam_answers`).
  Future<List<PhotoExamAnswer>> photoExamAnswers(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _client.rpc<List<dynamic>>(
      'photo_exam_answers',
      params: {'p_listings': ids},
    );
    return [
      for (final row in rows)
        PhotoExamAnswer.fromRow(row as Map<String, dynamic>),
    ];
  }

  /// Lets the database call Supabase Auth's admin API (accounts made from
  /// invites in the app) with this run's address and key; stored in the
  /// Vault, only when they changed.
  Future<void> storeServiceAccess(String url, String key) async {
    await _client.rpc<Object?>(
      'store_service_access',
      params: {'p_url': url, 'p_key': key},
    );
  }

  /// Our Web Push key pair; made and stored on the first run.
  Future<VapidKeys> pushKeys() async {
    Future<VapidKeys?> read() async {
      final rows = await _client.rpc<Object?>('push_keys') as List<dynamic>;
      if (rows.isEmpty) return null;
      final row = rows.first as Map<String, dynamic>;
      return VapidKeys.fromBase64(
        row['private_key'] as String,
        row['public_key'] as String,
      );
    }

    final stored = await read();
    if (stored != null) return stored;
    final keys = VapidKeys.generate();
    await _client.rpc<Object?>(
      'store_push_keys',
      params: {
        'p_public_key': keys.publicBase64,
        'p_private_key': keys.privateBase64,
      },
    );
    // Another run may have stored its pair first: use the stored one.
    return await read() ?? keys;
  }

  /// Every account's devices, by account.
  Future<Map<String, List<PushTarget>>> pushTargets() async {
    final rows = await _client
        .from('push_subscriptions')
        .select('endpoint, user_id, p256dh, auth');
    final byUser = <String, List<PushTarget>>{};
    for (final r in rows) {
      byUser
          .putIfAbsent(r['user_id'] as String, () => [])
          .add(
            PushTarget(
              endpoint: r['endpoint'] as String,
              p256dh: r['p256dh'] as String,
              auth: r['auth'] as String,
            ),
          );
    }
    return byUser;
  }

  /// A live listing for an example alert (the app's test notifications):
  /// the best Deal Score among [userId]'s models, or among all when the
  /// account follows none (or isn't given).
  Future<Map<String, dynamic>?> sampleListing(String? userId) async {
    final models = userId == null
        ? const <String>[]
        : [
            for (final r
                in await _client
                    .from('user_models')
                    .select('motorcycle_id')
                    .eq('user_id', userId)
                    .eq('tracked', true))
              r['motorcycle_id'] as String,
          ];
    var query = _client
        .from('listings')
        .select(
          'id, brand, model, url, year, mileage, price, deal_score, location',
        )
        .inFilter('status', ['active', 'price_changed'])
        .isFilter('duplicate_of', null)
        .not('motorcycle_id', 'is', null)
        .not('price', 'is', null);
    if (models.isNotEmpty) query = query.inFilter('motorcycle_id', models);
    final rows = await query
        .order('deal_score', ascending: false, nullsFirst: false)
        .limit(1);
    return rows.isEmpty ? null : rows.single;
  }

  /// Marks answered the valuations waiting for a model the run that started
  /// at [startedAt] read, with their values (`answer_bike_value_requests`).
  Future<List<BikeValueAnswer>> answerBikeValues(DateTime startedAt) async {
    final rows = await _client.rpc<List<dynamic>>(
      'answer_bike_value_requests',
      params: {'p_started_at': startedAt.toUtc().toIso8601String()},
    );
    return [
      for (final row in rows)
        BikeValueAnswer.fromRow(row as Map<String, dynamic>),
    ];
  }

  /// The account that last started [workflow] from the app since [since].
  Future<String?> lastWorkflowStarter(String workflow, DateTime since) async {
    final rows = await _client
        .from('workflow_starts')
        .select('started_by')
        .eq('workflow', workflow)
        .gte('started_at', since.toUtc().toIso8601String())
        .not('started_by', 'is', null)
        .order('started_at', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : rows.single['started_by'] as String;
  }

  /// The admins' accounts.
  Future<List<String>> adminIds() async {
    final rows = await _client.from('app_admins').select('user_id');
    return [for (final r in rows) r['user_id'] as String];
  }

  /// Devices whose push service says they no longer exist.
  Future<void> forgetPushTargets(List<String> endpoints) async {
    if (endpoints.isEmpty) return;
    await _client
        .from('push_subscriptions')
        .delete()
        .inFilter('endpoint', endpoints);
  }

  /// Devices that received a push now.
  Future<void> markPushTargetsUsed(List<String> endpoints) async {
    if (endpoints.isEmpty) return;
    await _client
        .from('push_subscriptions')
        .update({'last_sent_at': DateTime.now().toUtc().toIso8601String()})
        .inFilter('endpoint', endpoints);
  }

  Future<int> markNotified(List<String> alertIds) async {
    if (alertIds.isEmpty) return 0;
    final result = await _client.rpc<Object?>(
      'mark_alerts_notified',
      params: {'p_ids': alertIds},
    );
    return rpcCount(result);
  }
}
