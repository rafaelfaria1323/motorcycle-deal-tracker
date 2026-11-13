import '../entities/ownership_settings.dart';

abstract interface class OwnershipSettingsRepository {
  /// The current user's settings; the defaults when none were saved.
  Future<OwnershipSettings> get();

  /// Saves the current user's cost figures (all but the rider's height).
  Future<void> save(OwnershipSettings settings);

  /// Saves only the current user's height in cm (null: forget it).
  Future<void> saveRiderHeight(int? centimetres);
}
