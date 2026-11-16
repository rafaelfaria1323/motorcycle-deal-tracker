import '../store/push_store.dart';
import 'notification_text.dart';
import 'push_test.dart';
import 'web_push.dart';

/// A warning the database keeps for the admins (`admin_notices`, N.114:
/// the collection watchdog, the GitHub token, the space pruning, the
/// yearly tax tables), pushed to their devices in place of Telegram.
class const AdminNotice({
  required final int id,
  required final String kind,
  required final Map<String, dynamic> details,
  required final DateTime createdAt,
}) {
  /// A row of `take_admin_notices`.
  factory AdminNotice.fromRow(Map<String, dynamic> row) => AdminNotice(
    id: (row['id'] as num).toInt(),
    kind: row['kind'] as String,
    details: (row['details'] as Map<String, dynamic>?) ?? const {},
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}

/// The kinds `add_admin_notice` accepts (its check constraint).
const adminNoticeKinds = [
  'collection_stopped',
  'collection_resumed',
  'github_token_refused',
  'github_token_expiring',
  'listings_pruned',
  'tax_tables',
];

/// How long a notice waits for a device to take it: after that it is
/// marked sent anyway (a stale warning helps nobody).
const adminNoticeMaxWait = Duration(hours: 24);

/// The notification of [notice]; a tap opens "Estado da recolha".
Map<String, Object?> adminNoticePush(
  AdminNotice notice, {
  NotificationLanguage language = .portuguese,
}) {
  final d = notice.details;
  final (title, body) = switch (notice.kind) {
    'collection_stopped' => language.collectionStopped(
      '${d['hours'] ?? '?'}',
      '${d['last_run'] ?? '?'}',
    ),
    'collection_resumed' => language.collectionResumed,
    'github_token_refused' => language.githubTokenRefused(
      '${d['http_status'] ?? '?'}',
    ),
    'github_token_expiring' => language.githubTokenExpiring(
      '${d['expires_on'] ?? '?'}',
    ),
    'listings_pruned' => language.listingsPruned(
      '${d['deleted'] ?? '?'}',
      '${d['database_mb'] ?? '?'}',
    ),
    'tax_tables' => language.taxTablesChanged('${d['year'] ?? '?'}', [
      for (final line in d['differences'] as List<dynamic>? ?? const [])
        '$line',
    ]),
    final kind => (kind, ''),
  };
  return {
    'title': title,
    'body': body,
    'url': '/#/collection-status',
    'tag': 'admin-${notice.kind}',
    'language': language.code,
  };
}

/// Pushes the notices waiting to every admin's devices. A notice is marked
/// sent once a device took it, when no admin has a device, or once it is
/// [adminNoticeMaxWait] old; otherwise the next sender (notices.yml or a
/// collection's report) tries again.
Future<({int notices, int sent})> sendAdminNotices(
  PushStore store,
  WebPushSender push, {
  DateTime? now,
}) async {
  final notices = await store.takeAdminNotices();
  if (notices.isEmpty) return (notices: 0, sent: 0);
  final at = now ?? DateTime.now().toUtc();
  final admins = await store.adminIds();
  var marked = 0;
  var sent = 0;
  for (final notice in notices) {
    final result = await pushToUsers(
      store,
      push,
      admins,
      (_, language) => adminNoticePush(notice, language: language),
    );
    sent += result.sent;
    if (result.devices == 0 ||
        result.sent > 0 ||
        at.difference(notice.createdAt) >= adminNoticeMaxWait) {
      await store.markAdminNoticeSent(notice.id);
      marked++;
    }
  }
  return (notices: marked, sent: sent);
}
