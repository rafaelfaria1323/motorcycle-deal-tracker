import '../../../core/platform/push.dart';

abstract interface class PushRepository {
  /// The key devices subscribe with; null until the collector's first run
  /// made it.
  Future<String?> publicKey();

  /// Stores this device for the signed-in account.
  Future<void> save(PushSubscription subscription);

  /// Forgets this device.
  Future<void> remove(String endpoint);
}
