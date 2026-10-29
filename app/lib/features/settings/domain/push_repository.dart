import '../../../core/platform/push.dart';
import 'quiet_hours.dart';

abstract interface class PushRepository {
  /// The key devices subscribe with; null until the collector's first run
  /// made it.
  Future<String?> publicKey();

  /// Stores this device for the signed-in account.
  Future<void> save(PushSubscription subscription);

  /// Forgets this device.
  Future<void> remove(String endpoint);

  /// The signed-in account's quiet hours (the default without a row).
  Future<QuietHours> quietHours();

  /// Saves them for the signed-in account (all its devices).
  Future<void> saveQuietHours(QuietHours hours);
}
