import '../entities/ownership_settings.dart';

abstract interface class OwnershipSettingsRepository {
  /// The current user's settings; the defaults when none were saved.
  Future<OwnershipSettings> get();

  /// Saves the current user's settings (all of them).
  Future<void> save(OwnershipSettings settings);
}
