import 'package:equatable/equatable.dart';

import '../../domain/entities/favourite.dart';

enum FavouritesStatus { initial, loading, success, failure }

class const FavouritesState({
  final FavouritesStatus status = FavouritesStatus.initial,

  /// Newest first.
  final List<Favourite> favourites = const [],

  /// The list is this device's last copy: the database could not be read
  /// (N.66).
  final bool fromDevice = false,

  /// Listings whose checklist is kept on this device until the database
  /// takes it (no connection when it was marked).
  final Set<String> unsent = const {},
}) extends Equatable {
  Favourite? favouriteOf(String listingId) =>
      favourites.where((f) => f.listingId == listingId).firstOrNull;

  bool isFavourite(String listingId) => favouriteOf(listingId) != null;

  FavouritesState copyWith({
    FavouritesStatus? status,
    List<Favourite>? favourites,
    bool? fromDevice,
    Set<String>? unsent,
  }) {
    return FavouritesState(
      status: status ?? this.status,
      favourites: favourites ?? this.favourites,
      fromDevice: fromDevice ?? this.fromDevice,
      unsent: unsent ?? this.unsent,
    );
  }

  @override
  List<Object?> get props => [status, favourites, fromDevice, unsent];
}
