import '../entities/listing_alert.dart';

abstract interface class AlertsRepository {
  /// The current user's alerts, newest first.
  Future<List<ListingAlert>> getAll();

  Future<void> markRead(String id);

  Future<void> markAllRead();
}
