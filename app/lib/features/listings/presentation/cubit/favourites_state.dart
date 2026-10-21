import 'package:equatable/equatable.dart';

import '../../domain/entities/favourite.dart';

enum FavouritesStatus { initial, loading, success, failure }

class FavouritesState extends Equatable {
  const FavouritesState({
    this.status = FavouritesStatus.initial,
    this.favourites = const [],
  });

  final FavouritesStatus status;

  /// Newest first.
  final List<Favourite> favourites;

  Favourite? favouriteOf(String listingId) =>
      favourites.where((f) => f.listingId == listingId).firstOrNull;

  bool isFavourite(String listingId) => favouriteOf(listingId) != null;

  FavouritesState copyWith({
    FavouritesStatus? status,
    List<Favourite>? favourites,
  }) {
    return FavouritesState(
      status: status ?? this.status,
      favourites: favourites ?? this.favourites,
    );
  }

  @override
  List<Object?> get props => [status, favourites];
}
