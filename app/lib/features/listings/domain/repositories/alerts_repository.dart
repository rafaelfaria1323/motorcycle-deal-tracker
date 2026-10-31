import '../entities/listing_alert.dart';

abstract interface class AlertsRepository {
  /// A page of the current user's undismissed alerts, newest first; only
  /// those of [types] unless empty.
  Future<List<ListingAlert>> getPage({
    required int limit,
    Set<AlertType> types = const {},
    int offset = 0,
  });

  /// How many of the current user's undismissed alerts are unread, of
  /// every type (the badge on Alertas).
  Future<int> countUnread();

  Future<void> markRead(String id);

  Future<void> markAllRead();

  /// Hides an alert while retaining notification and deduplication history.
  Future<void> dismiss(String id);

  /// Hides every read alert, as [dismiss] does one; returns how many.
  Future<int> dismissRead();
}
