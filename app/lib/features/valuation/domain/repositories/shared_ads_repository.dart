import '../entities/shared_ad.dart';

/// The iPhone shortcut's key and the ads it sent (N.110).
abstract interface class SharedAdsRepository {
  /// When the account's key was made; null when it has none.
  Future<DateTime?> keyCreatedAt();

  /// A new key (the old one stops working). Only its fingerprint is kept,
  /// so this is the one time it can be shown.
  Future<String> createKey();

  /// Turns the key off.
  Future<void> removeKey();

  /// The ads waiting, newest first.
  Future<List<SharedAd>> waiting();

  /// Takes [id] out of the inbox.
  Future<void> dismiss(String id);
}
