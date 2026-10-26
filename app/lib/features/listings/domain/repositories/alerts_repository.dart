import '../entities/listing_alert.dart';

abstract interface class AlertsRepository {
  /// The current user's undismissed alerts, newest first.
  Future<List<ListingAlert>> getAll();

  Future<void> markRead(String id);

  Future<void> markAllRead();

  /// Hides an alert while retaining notification and deduplication history.
  Future<void> dismiss(String id);
}
