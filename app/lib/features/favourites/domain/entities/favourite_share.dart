import 'package:equatable/equatable.dart';

/// The account's own shared list (16.11): who sees it, and the link not
/// yet used.
class const FavouriteShare({
  /// The account that sees the list; null when nobody does yet.
  final String? viewerEmail,

  /// The link's code while it waits to be used (14 days, once).
  final String? code,
  final DateTime? codeExpiresAt,
}) extends Equatable {
  static const none = FavouriteShare();

  bool get waiting => code != null;

  @override
  List<Object?> get props => [viewerEmail, code, codeExpiresAt];
}

/// A list another account shares with this one.
class const SharedList({
  required final String ownerId,
  required final String ownerEmail,
}) extends Equatable {
  @override
  List<Object?> get props => [ownerId, ownerEmail];
}
